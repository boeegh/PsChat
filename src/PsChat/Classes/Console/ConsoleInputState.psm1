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
