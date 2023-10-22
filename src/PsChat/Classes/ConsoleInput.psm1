using namespace System
using namespace System.Runtime.InteropServices

class ConsoleInputState {
    [int] $CursorPos = 0
    [string] $Text = ""
    [string] $PreviousText = ""
    [int] $InitialCursorTop = 0
    [int] $InitialCursorLeft = 0

    ConsoleInputState() {
        $this.InitialCursorTop = [Console]::CursorTop
        $this.InitialCursorLeft = [Console]::CursorLeft
    }

    [int] WindowWidth() {
        return [Console]::BufferWidth
    }

    [int] WindowHeight() {
        return [Console]::BufferHeight
    }
}

class ConsoleInputExtension {
    [bool] ProcessKey([ConsoleInputState]$state, [ConsoleKeyInfo]$key) {
        return $false
    }
}

class ConsoleInputHistory : ConsoleInputExtension {
    [int] $MaxHistorySize = 100
    [int] $CurrentHistoryIndex = 0
    [string[]] $History = @()

    [bool] ProcessKey([ConsoleInputState]$state, [ConsoleKeyInfo]$key) {
        if($key.Key -eq [ConsoleKey]::UpArrow) {
            $state.Text = $this.GetPreviousHistory()
            return $true
        }
        elseif($key.Key -eq [ConsoleKey]::DownArrow) {
            $state.Text = $this.GetNextHistory()
            return $true
        }
        return $false
    }

    [string] GetPreviousHistory() {
        $this.CurrentHistoryIndex--
        if($this.CurrentHistoryIndex -lt 0) {
            $this.CurrentHistoryIndex = 0
        }
        return $this.History[$this.CurrentHistoryIndex]
    }

    [string] GetNextHistory() {
        if($this.CurrentHistoryIndex -eq $this.History.Count) {
            return ""
        }
        $this.CurrentHistoryIndex++
        return $this.History[$this.CurrentHistoryIndex]
    }

    AddHistory([string]$text) {
        $this.History += $text
        if($this.History.Count -gt $this.MaxHistorySize) {
            $this.History = $this.History[1..$this.MaxHistorySize]
        }
        $this.CurrentHistoryIndex = $this.History.Count
    }
}

class ConsoleInput {
    [bool] $Debug = $false
    [bool] $TreatControlCAsInput = $false
    [bool] $NewLineOnEnter = $true
    [ConsoleInputExtension[]] $Extensions = @()
    [ConsoleKey[]] $ExitKeys = @([ConsoleKey]::Enter, [ConsoleKey]::Escape)
    [bool] $AltEnterBehavior = $false
    [object] $ChordMap = @{
        [int][ConsoleKey]::V = { $this.Paste($state) }
        [int][ConsoleKey]::E = { $this.AltEnterBehavior = !$this.AltEnterBehavior }
    }

    static [string] Read() {
        $ci = [ConsoleInput]::new()
        return $ci.ReadLine()
    }

    [bool] IsMacOS() {
        return [RuntimeInformation]::IsOSPlatform([OSPlatform]::OSX)
    }

    [bool] IsExitKey($state, $key) {
        if($key.Modifiers -band [ConsoleModifiers]::Shift) {
            return $false
        }

        if($key.Key -eq [ConsoleKey]::Enter -and $this.AltEnterBehavior) {
            return $false
        }

        return ($this.ExitKeys -contains $key.Key)
    }

    [bool] IsIgnored($key) {
        return `
            $key.Modifiers -band [ConsoleModifiers]::Alt -or `
            $key.Modifiers -band [ConsoleModifiers]::Control
    }

    [bool] IsChord($key) {
        if(($key.KeyChar -eq "π" -and $this.IsMacOS())) {
            return $true
        }
        if($key.KeyChar -eq "p" -and $key.Modifiers -band [ConsoleModifiers]::Alt) {
            return $true
        }
        return $false
    }

    [int] GetNavigationDelta($state, $key) {
        # todo: support for home and key-keys
        # note: for some reason, its required to cast the enum to int explicitly
        switch ([int]$key.Key) {
            ([int][ConsoleKey]::LeftArrow) {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) { return -10 } else { return -1 }
            }
            ([int][ConsoleKey]::RightArrow) {
                if ($key.Modifiers -band [ConsoleModifiers]::Control) { return 10 } else { return 1 }
            }

            # note: MacOS handles arrow keys combined with 'option' funny
            ([int][ConsoleKey]::B) {
                if ($this.IsMacOS() -and $key.Modifiers -band [ConsoleModifiers]::Alt) { return -10 }
            }
            ([int][ConsoleKey]::F) {
                if ($this.IsMacOS() -and $key.Modifiers -band [ConsoleModifiers]::Alt) { return 10 }
            }
        }

        return 0
    }

    NavigateTextLeft($state, [int]$delta) {
        $state.CursorPos += $delta
        if($state.CursorPos -lt 0) {
            $state.CursorPos = 0
        }
        if($state.CursorPos -gt $state.Text.Length) {
            $state.CursorPos = $state.Text.Length
        }

        $this.UpdateCursorPosition($state)
     }

    UpdateCursorPosition($state) {
        if($state.CursorPos -gt $state.Text.Length) {
            $state.CursorPos = $state.Text.Length
        }

        # problem: when inserting newline, vertical overflow is not handled properly

        # calculate actual cursor pos when text includes newlines
        $leftText = $state.Text.Substring(0, $state.CursorPos)
        $left = $state.InitialCursorLeft
        $top = $state.InitialCursorTop
        foreach($char in $leftText.ToCharArray()) {            
            if($char -eq "`n") {
                $top += 1
                $left = 0
                continue
            }

            $left += if($char -eq "`t") { 4 } else { 1 }
            if($left -ge $state.WindowWidth()) {
                $left = 0
                $top += 1
            }
        }

        # handle vertical overflow
        # if($top -ge $state.WindowHeight()) {           
        #     $topDelta = $top - $state.WindowHeight() + 1
        #     # [Console]::Write("`n" * $topDelta)
        #     $state.InitialCursorTop -= $topDelta
        #     $top = $state.WindowHeight() - $topDelta
        # }
        [Console]::CursorTop = $top
        [Console]::CursorLeft = $left
    }

    RemoveCharacterLeft($state) {
        if($state.CursorPos -eq 0) {
            return
        }
        $state.Text = $state.Text.Substring(0, $state.CursorPos - 1) + $state.Text.Substring($state.CursorPos)
        $this.WriteText($state)
    }

    RemoveCharacterRight($state) {
        if($state.CursorPos -gt $state.Text.Length - 1) {
            return
        }
        $state.Text = $state.Text.Substring(0, $state.CursorPos) + $state.Text.Substring($state.CursorPos + 1)
        $this.WriteText($state)
    }

    InsertCharacter($state, $keyChar) {
        $state.Text = $state.Text.Substring(0, $state.CursorPos) + $keyChar + $state.Text.Substring($state.CursorPos)
        $state.CursorPos += 1
        $this.WriteText($state)
    }

    UpdateDebugInfo($state, $key, $message = "") {
        if(!$this.Debug) {
            return
        }
        [Console]::CursorTop = 5
        [Console]::CursorLeft = 0
        [Console]::WriteLine("Debug/Message: $message $(" "*40)")
        [Console]::WriteLine("Key: $($key.KeyChar) $(" "*4)")
        [Console]::WriteLine("KeyChar.IsControl: $([char]::IsControl($key.KeyChar)) $(" "*4)")
        [Console]::WriteLine("WindowWidth: $($state.WindowWidth()) $(" "*4)")
        [Console]::WriteLine("WindowHeight: $($state.WindowHeight()) $(" "*4)")
        [Console]::WriteLine($($state | ConvertTo-Json -Depth 10))
        [Console]::WriteLine($($key | ConvertTo-Json -Depth 10))
        $this.UpdateCursorPosition($state)
    }

    WriteText($state) {
        [Console]::CursorVisible = $false

        # $topBefore = [Console]::CursorTop

        # write text while clearing unused space
        [Console]::CursorTop = $state.InitialCursorTop
        [Console]::CursorLeft = $state.InitialCursorLeft
        $top = $state.InitialCursorTop
        foreach($char in $state.Text.ToCharArray()) {            
            if($char -eq "`n") {
                # clear rest of the line
                $top += 1
                [Console]::Write(" " * ($state.WindowWidth() - [Console]::CursorLeft))
                continue
            }
            [Console]::Write($char)
            if([Console]::CursorLeft -eq 0) {
                $top += 1
            }
        }
        # clear final line
        [Console]::Write(" " * ($state.WindowWidth() - [Console]::CursorLeft - 1))

        $scrolled = $false
        $topAfter = [Console]::CursorTop
        if($top -eq $state.WindowHeight() -and $topAfter -eq $state.WindowHeight() - 1) {
            $scrolled = $true
            $state.InitialCursorTop -= 1
        }

        [Console]::Title = "ctop: $($state.CursorPos) scrolled: $scrolled, topAfter: $topAfter, top: $top,height: $($state.WindowHeight())"
        # if($topAfter -gt $topBefore) {
        #     #$topDelta = $topAfter - $topBefore
        #     #$state.InitialCursorTop -= $topDelta
        # }

        $this.UpdateCursorPosition($state)
        $state.PreviousText = $state.Text
        [Console]::CursorVisible = $true
    }

    Paste($state) {
        $content = (Get-Clipboard -Raw | Select-Object -First 1)
        $contentRemaining = $state.Text.Substring($state.CursorPos)
        $state.Text = $state.Text.Substring(0, $state.CursorPos) + $content + $contentRemaining
        $state.CursorPos += $content.Length
        $this.WriteText($state)
        $this.UpdateCursorPosition($state)
    }

    [string] ReadLine() {
        return $this.ReadLine("")
    }

    [string] ReadLine($prompt) {
        Write-Host $prompt -NoNewline

        $state = [ConsoleInputState]::new()
        [Console]::TreatControlCAsInput = $this.TreatControlCAsInput
        do
        {
            $key = [Console]::ReadKey($true)

            $this.Extensions | ForEach-Object {
                if($_.ProcessKey($state, $key)) {
                    $this.WriteText($state)
                }
            }

            $this.UpdateDebugInfo($state, $key, "")

            # exit (based on ExitKeys property)
            if ($this.IsExitKey($state, $key)) {
                if($this.NewLineOnEnter) {
                    [Console]::WriteLine()
                }
                break
            }

            # navigation (arrow keys)
            $delta = $this.GetNavigationDelta($state, $key)
            if($delta -ne 0) {
                $this.NavigateTextLeft($state, $delta)
                $this.UpdateDebugInfo($state, $key, "")
                continue
            }

            # deleting (backspace, delete)
            if ($key.Key -eq [ConsoleKey]::BackSpace) {
                $this.RemoveCharacterLeft($state)
                $this.UpdateDebugInfo($state, $key, "")
                # $this.NavigateTextLeft($state, -1)
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Delete) {
                $this.RemoveCharacterRight($state)
                $this.UpdateDebugInfo($state, $key, "")
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Escape) {
                $state.Text = ""
                $state.CursorPos = 0
                $this.WriteText($state)
                continue
            }

            # chords allow for alt-p + v to paste
            if($this.IsChord($key)) {
                $map = $this.ChordMap
                $key = [int][Console]::ReadKey($true).Key
                if($map[$key]) {
                    $map[$key].Invoke()
                }
                continue
            }

            # if alternative enter behavior is enabled (or shift is down on pc), enter will insert a newline
            if (($this.AltEnterBehavior -or $key.Modifiers -band [ConsoleModifiers]::Shift) -and $key.Key -eq [ConsoleKey]::Enter) {
                $topPreNewLine = [Console]::CursorTop
                $this.InsertCharacter($state, "`n")
                [Console]::CursorLeft = 0
                $top = [Console]::CursorTop
                $this.UpdateDebugInfo($state, $key, "AltEnterBehavior: (pre):$topPreNewLine -> (post):$top")
                # if($top -gt $topPreNewLine) {
                #     $topDelta = $top - $topPreNewLine
                #     $state.InitialCursorTop -= $topDelta
                #     $this.UpdateCursorPosition($state)
                # }
                continue
            }

            # ignored keys (alt, ctrl, control characters)
            if ($this.IsIgnored($key) -or [char]::IsControl($key.KeyChar)) {
                continue
            }

            $this.InsertCharacter($state, $key.KeyChar)
            $this.UpdateDebugInfo($state, $key, "")

        } while ($true)

        return $state.Text
    }
}

if($args -eq "-Debug" -or $true) {
    clear
    # Write-Host "`n" * 20
    # Write-Host $args
    [Console]::Write("`n" * 30)
    $input = [ConsoleInput]::new()
    $input.Debug = $true
    $input.AltEnterBehavior = $true
    $input.ReadLine("Enter text $(Get-Date): ")
}
