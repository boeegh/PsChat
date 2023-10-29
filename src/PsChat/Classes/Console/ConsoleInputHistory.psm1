class ConsoleInputExtension {
  [bool] ProcessKey([object]$consoleInput, [ConsoleKeyInfo]$key) {
      return $false
  }
}

class ConsoleInputHistory : ConsoleInputExtension {
  [int] $MaxHistorySize = 100
  [int] $CurrentHistoryIndex = 0
  [string[]] $History = @()

  [bool] ProcessKey([object]$consoleInput, [ConsoleKeyInfo]$key) {
      $s = $consoleInput.State
      if($consoleInput.AltEnterBehavior -eq $true) {
          return $false
      }

      if($key.Key -eq [ConsoleKey]::UpArrow) {
          $s.Text = $this.GetPreviousHistory()
          return $true
      }
      elseif($key.Key -eq [ConsoleKey]::DownArrow) {
          $s.Text = $this.GetNextHistory()
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