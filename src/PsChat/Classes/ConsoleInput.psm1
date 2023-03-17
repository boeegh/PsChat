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

    static [string] Read() {
        $ci = [ConsoleInput]::new()
        return $ci.ReadLine()
    }

    [bool] IsMacOS() {
        return [RuntimeInformation]::IsOSPlatform([OSPlatform]::OSX)
    }

    [bool] IsExitKey($key) {
#        return ($key.Key -eq [ConsoleKey]::Escape -or $key.Key -eq [ConsoleKey]::Enter)
        return ($key.Key -eq [ConsoleKey]::Enter)
    }

    [bool] IsIgnored($key) {
        return `
            $key.Modifiers -band [ConsoleModifiers]::Alt -or `
            $key.Modifiers -band [ConsoleModifiers]::Control
    }

    [int] GetNavigationDelta($state, $key) {
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
        $currentLeft = $state.InitialCursorLeft + $state.CursorPos
        $topDelta = [Math]::Floor($currentLeft / $state.WindowWidth())
        $leftDelta = $currentLeft % $state.WindowWidth()
        [Console]::CursorTop = $state.InitialCursorTop + $topDelta
        [Console]::CursorLeft = $leftDelta
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
        [Console]::WriteLine("Debug/Message: $message")
        [Console]::WriteLine("Key: $($key.KeyChar)")
        [Console]::WriteLine("KeyChar.IsControl: $([char]::IsControl($key.KeyChar))")
        [Console]::WriteLine("WindowWidth: $($state.WindowWidth())")
        [Console]::WriteLine("WindowHeight: $($state.WindowHeight())")
        [Console]::WriteLine($($state | ConvertTo-Json -Depth 10))
        [Console]::WriteLine($($key | ConvertTo-Json -Depth 10))
        $this.UpdateCursorPosition($state)
    }

    WriteText($state) {
        [Console]::CursorTop = $state.InitialCursorTop
        [Console]::CursorLeft = $state.InitialCursorLeft
        [Console]::Write("$($state.Text)")

        # overwrite remaining characters with spaces
        $shorter = $state.PreviousText.Length - $state.Text.Length
        if($shorter -gt 0) {
            [Console]::Write(" " * $shorter)
        }

        $this.UpdateCursorPosition($state)
        $state.PreviousText = $state.Text
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

            # exit (enter or escape)
            if ($this.IsExitKey($key)) {
                if($this.NewLineOnEnter) {
                    [Console]::WriteLine()
                }
                break
            }

            # navigation (arrow keys)
            $delta = $this.GetNavigationDelta($state, $key)
            if($delta -ne 0) {
                $this.NavigateTextLeft($state, $delta)
                continue
            }

            # deleting (backspace, delete)
            if ($key.Key -eq [ConsoleKey]::BackSpace) {
                $this.RemoveCharacterLeft($state)
                $this.NavigateTextLeft($state, -1)
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Delete) {
                $this.RemoveCharacterRight($state)
                continue
            }

            if ($key.Key -eq [ConsoleKey]::Escape) {
                $state.Text = ""
                $state.CursorPos = 0
                $this.WriteText($state)
                continue
            }

            # ignored keys (alt, ctrl, control characters)
            if ($this.IsIgnored($key) -or [char]::IsControl($key.KeyChar)) {
                continue
            }

            $this.InsertCharacter($state, $key.KeyChar)

        } while ($true)

        return $state.Text
    }
}
