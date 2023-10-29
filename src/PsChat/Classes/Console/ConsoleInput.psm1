using module ".\ConsoleInputState.psm1"
using module ".\ConsoleInputHistory.psm1"
using namespace System
using namespace System.Runtime.InteropServices

class ConsoleInput {
    [bool] $Debug = $false
    [bool] $TreatControlCAsInput = $false
    [bool] $NewLineOnEnter = $true
    [ConsoleInputExtension[]] $Extensions = @()
    [ConsoleKey[]] $ExitKeys = @([ConsoleKey]::Enter, [ConsoleKey]::Escape)
    [bool] $AltEnterBehavior = $false
    [object] $ChordMap = @{
        [int][ConsoleKey]::V = { $this.Paste() }
        [int][ConsoleKey]::E = { $this.AltEnterBehavior = !$this.AltEnterBehavior }
    }
    [ConsoleInputState] $State = [ConsoleInputState]::new()

    static [string] Read() {
        $ci = [ConsoleInput]::new()
        return $ci.ReadLine()
    }

    [bool] PsClassic() {
        return (Get-Host).Version.Major -lt 6
    }
    
    [bool] IsMacOS() {
        if($this.PsClassic()) {
            return $false
        }
        return [RuntimeInformation]::IsOSPlatform([OSPlatform]::OSX)
    }

    [bool] IsWindows() {
        return [RuntimeInformation]::IsOSPlatform([OSPlatform]::Windows)
    }

    [bool] IsExitKey($key) {
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

    [int] GetCursorDiffVertical([int]$direction) {
        if($this.AltEnterBehavior -eq $false) {
            return 0
        }

        # get distance to next newline in specified direction
        $delta = 0
        $pos = $this.state.CursorPos
        $text = $this.state.Text
        while($pos -ge 0 -and $pos -le $text.Length) {
            if($text[$pos] -eq "`n") {
                $delta += $direction
                break
            }
            if([Math]::Abs($delta) -ge $this.state.WindowWidth()) {
                break
            }
            $pos += $direction
            $delta += $direction
        }

        return $delta
     }    

    [int] GetNavigationDelta($key) {
        # todo: support for home and key-keys
        # note: for some reason, its required to cast the enum to int explicitly
        switch ([int]$key.Key) {
            ([int][ConsoleKey]::UpArrow) {
                return $this.GetCursorDiffVertical(-1)
            }
            ([int][ConsoleKey]::DownArrow) {
                return $this.GetCursorDiffVertical(1)
            }

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

    NavigateTextLeft([int]$delta) {
        $this.State.CursorPos += $delta
        if($this.State.CursorPos -lt 0) {
            $this.State.CursorPos = 0
        }
        if($this.State.CursorPos -gt $this.State.Text.Length) {
            $this.State.CursorPos = $this.State.Text.Length
        }

        $this.UpdateCursorPosition()
     }

    UpdateCursorPosition() {
        if($this.state.CursorPos -gt $this.state.Text.Length) {
            $this.state.CursorPos = $this.state.Text.Length
        }

        $leftText = $this.state.Text.Substring(0, $this.state.CursorPos)
        $end = $this.CalculateTextEnd($this.state.InitialCursorLeft, $this.state.InitialCursorTop, $leftText)

        [Console]::CursorTop = $end.top
        [Console]::CursorLeft = $end.left
    }

    RemoveCharacterLeft() {
        if($this.state.CursorPos -eq 0) {
            return
        }
        $rest = $this.state.Text.Substring($this.state.CursorPos)
        $this.state.Text = $this.state.Text.Substring(0, $this.state.CursorPos - 1) + $rest

        $this.NavigateTextLeft(-1)

        $this.Update()
    }

    RemoveCharacterRight() {
        if($this.state.CursorPos -gt $this.state.Text.Length - 1) {
            return
        }
        $this.state.Text = $this.state.Text.Substring(0, $this.state.CursorPos) + $this.state.Text.Substring($this.state.CursorPos + 1)
        $this.Update()
    }

    InsertCharacter($keyChar) {
        $this.state.Text = $this.state.Text.Substring(0, $this.state.CursorPos) + $keyChar + $this.state.Text.Substring($this.state.CursorPos)
        $this.state.CursorPos += 1
        $this.Update()
    }

    UpdateDebugInfo($key, $message="") {
        if(!$this.Debug) {
            return
        }
        [Console]::CursorTop = 5
        [Console]::CursorLeft = 0
        [Console]::WriteLine("Debug/Message: $message $(" "*40)")
        [Console]::WriteLine("Key: $($key.KeyChar) $(" "*4)")
        [Console]::WriteLine("KeyChar.IsControl: $([char]::IsControl($key.KeyChar)) $(" "*4)")
        [Console]::WriteLine("WindowWidth: $($this.state.WindowWidth()) $(" "*4)")
        [Console]::WriteLine("WindowHeight: $($this.state.WindowHeight()) $(" "*4)")
        [Console]::WriteLine($($this.state | ConvertTo-Json -Depth 10))
        [Console]::WriteLine($($key | ConvertTo-Json -Depth 10))
        $this.UpdateCursorPosition()
    }

    [object] CalculateTextEnd($initialLeft, $initialTop, $text) {
        $left = $initialLeft
        $top = $initialTop

        foreach($char in $text.ToCharArray()) {            
            if($char -eq "`n") {
                $top += 1
                $left = 0
                continue
            }

            $left += if($char -eq "`t") { 4 } else { 1 }
            if($left -ge $this.state.WindowWidth()) {
                $left = 0
                $top += 1
            }
        }
        
        return @{ top=$top; left=$left }
    }

    Update() {
        [Console]::CursorVisible = $false

        # clear existing content
        $blankText = $this.state.PreviousText -replace '[^\n\t]', ' '
        [Console]::CursorTop = $this.state.InitialCursorTop
        [Console]::CursorLeft = $this.state.InitialCursorLeft
        [Console]::Write($blankText)

        # debug background color
        $bgColor = [Console]::BackgroundColor
        # $this.Debug = $true
        if($this.Debug) {
            [Console]::BackgroundColor = [ConsoleColor]::DarkGray
        }

        # calculate actual space used by text
        $end = $this.CalculateTextEnd($this.state.InitialCursorLeft, $this.state.InitialCursorTop, $this.state.Text)
        $top = $end.top

        # if text is too long, scroll up
        if($top -gt $this.state.WindowHeight() - 1) {
            [Console]::CursorTop = $this.state.WindowHeight() - 1
            [Console]::CursorLeft = 0
            $delta = $top - $this.state.WindowHeight() + 1
            [Console]::Write("`n" * $delta)
            $this.state.InitialCursorTop -= $delta
        }
    
        # write text while clearing unused space
        [Console]::CursorTop = $this.state.InitialCursorTop
        [Console]::CursorLeft = $this.state.InitialCursorLeft
        [Console]::Write($this.state.Text)

        [Console]::BackgroundColor = $bgColor
        
        $this.UpdateCursorPosition()
        $this.state.PreviousText = $this.state.Text

        [Console]::CursorVisible = $true
    }

    Paste() {
        $content = (Get-Clipboard -Raw | Select-Object -First 1)
        if(!$content) {
            return
        }
        $contentRemaining = $this.state.Text.Substring($this.state.CursorPos)
        $this.state.Text = $this.state.Text.Substring(0, $this.state.CursorPos) + $content + $contentRemaining
        $this.state.CursorPos += $content.Length
        $this.Update()
        $this.UpdateCursorPosition()
    }

    [string] ReadLine() {
        return $this.ReadLine("")
    }

    [string] ReadLine($prompt) {
        Write-Host $prompt -NoNewline
        $this.State = [ConsoleInputState]::new()
        [Console]::TreatControlCAsInput = $this.TreatControlCAsInput
        do
        {
            $key = [Console]::ReadKey($true)

            $this.Extensions | ForEach-Object {
                if($_.ProcessKey($this, $key)) {
                    $this.Update()
                }
            }

            $this.UpdateDebugInfo($key, "")

            # exit (based on ExitKeys property)
            if ($this.IsExitKey($key)) {
                if($this.NewLineOnEnter) {
                    [Console]::WriteLine()
                }
                break
            }

            # navigation (arrow keys)
            $delta = $this.GetNavigationDelta($key)
            if($delta -ne 0) {
                $this.NavigateTextLeft($delta)
                $this.UpdateDebugInfo($key, "")
                continue
            }

            # deleting (backspace, delete)
            if ($key.Key -eq [ConsoleKey]::BackSpace) {
                $this.RemoveCharacterLeft()
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Delete) {
                $this.RemoveCharacterRight()
                $this.UpdateDebugInfo($key, "")
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Escape) {
                $this.State.Text = ""
                $this.State.CursorPos = 0
                $this.Update()
                continue
            }

            # chords allow for alt-p + v to paste
            if($this.IsChord($key)) {
                $title = ""
                if($this.IsWindows()) {
                    $title = [Console]::Title
                    $chords = $this.ChordMap.Keys | ForEach-Object { [char]$_ }
                    [Console]::Title = "Chord mode activated. Available chords: $($chords -join ", ")"
                }
                $map = $this.ChordMap
                $key = [int][Console]::ReadKey($true).Key
                if($this.IsWindows()) {
                    [Console]::Title = $title
                }
                if($map[$key]) {
                    $map[$key].Invoke()
                }
                continue
            }

            # if alternative enter behavior is enabled (or shift is down on pc), enter will insert a newline
            if (($this.AltEnterBehavior -or $key.Modifiers -band [ConsoleModifiers]::Shift) -and $key.Key -eq [ConsoleKey]::Enter) {
                $this.InsertCharacter("`n")
                [Console]::CursorLeft = 0
                continue
            }

            # ignored keys (alt, ctrl, control characters)
            if ($this.IsIgnored($key) -or [char]::IsControl($key.KeyChar)) {
                continue
            }

            $this.InsertCharacter($key.KeyChar)
            $this.UpdateDebugInfo($key, "")

        } while ($true)

        return $this.State.Text
    }
}

# poor mans testing:
# pushd ".\src\PsChat\Classes\Console\"; Invoke-Expression (Get-ChildItem -Path '.' -Filter '*.psm1' | ForEach-Object { Get-Content -Raw $_.FullName } | % {$_.replace("condbg","true")} | Out-String); popd
if($condbg) {
    clear
    # Write-Host "`n" * 20
    # Write-Host $args
    [Console]::Write("`n" * 30)
    $input = [ConsoleInput]::new()
    $input.Debug = $true
    $input.AltEnterBehavior = $true
    $input.ReadLine("Enter text $(Get-Date): ")
}
