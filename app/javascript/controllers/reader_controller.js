import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "editor",
    "fileInput",
    "fileName",
    "cursorPosition",
    "lineNumber",
    "columnNumber",
    "textLength"
  ]

  connect() {
    this.fileText = ""
    this.updateStatus()
  }

  async fileSelected() {
    const file = this.fileInputTarget.files[0]

    if (!file) {
      this.fileText = ""
      this.fileNameTarget.textContent = "none"
      return
    }

    this.fileText = await file.text()
    this.fileNameTarget.textContent = file.name
  }

  async replaceFromFile() {
    await this.ensureFileLoaded()
    this.replaceText(this.fileText)
  }

  async appendFromFile() {
    await this.ensureFileLoaded()
    this.appendText(this.fileText)
  }

  async insertFromFile() {
    await this.ensureFileLoaded()
    this.insertTextAtCursor(this.fileText)
  }

  async replaceFromClipboard() {
    const text = await this.readClipboard()
    this.replaceText(text)
  }

  async appendFromClipboard() {
    const text = await this.readClipboard()
    this.appendText(text)
  }

  async insertFromClipboard() {
    const text = await this.readClipboard()
    this.insertTextAtCursor(text)
  }

  replaceText(text) {
    this.editorTarget.value = text || ""
    this.editorTarget.focus()
    this.editorTarget.setSelectionRange(0, 0)
    this.updateStatus()
  }

  appendText(text) {
    const current = this.editorTarget.value
    this.editorTarget.value = current + (text || "")
    const pos = this.editorTarget.value.length
    this.editorTarget.focus()
    this.editorTarget.setSelectionRange(pos, pos)
    this.updateStatus()
  }

  insertTextAtCursor(text) {
    const editor = this.editorTarget
    const insertValue = text || ""
    const start = editor.selectionStart
    const end = editor.selectionEnd
    const before = editor.value.slice(0, start)
    const after = editor.value.slice(end)

    editor.value = before + insertValue + after

    const newPos = start + insertValue.length
    editor.focus()
    editor.setSelectionRange(newPos, newPos)
    this.updateStatus()
  }

  updateCursor() {
    this.updateStatus()
  }

  updateStatus() {
    const editor = this.editorTarget
    const cursor = editor.selectionStart || 0
    const text = editor.value || ""

    const beforeCursor = text.slice(0, cursor)
    const lines = beforeCursor.split("\n")
    const line = lines.length
    const column = lines[lines.length - 1].length + 1

    this.cursorPositionTarget.textContent = `char ${cursor}`
    this.lineNumberTarget.textContent = line
    this.columnNumberTarget.textContent = column
    this.textLengthTarget.textContent = text.length
  }

  async ensureFileLoaded() {
    const file = this.fileInputTarget.files[0]

    if (!file) {
      alert("Please choose a file first.")
      throw new Error("No file selected")
    }

    if (!this.fileText) {
      this.fileText = await file.text()
    }
  }

  async readClipboard() {
    try {
      const text = await navigator.clipboard.readText()

      if (!text) {
        alert("Clipboard is empty or does not contain text.")
      }

      return text
    } catch (error) {
      alert("Unable to read the clipboard. Your browser may require permission or a secure context.")
      throw error
    }
  }
}
