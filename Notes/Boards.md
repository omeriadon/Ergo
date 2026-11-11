# Boards and the canvas

Shared boards add rules for anything that writes to `boards`: see `SharingBoards.md`.

- A board (`Board`, in `BoardStore`, persisted with Defaults) is a canvas in the Board tab: `statements` joined by `links` ("premise of"), and `sources`. It always holds at least one statement or source. Boards are English only.
- A `BoardSource` is a block of text or a web link on the canvas. It can't take arrows. Links only ever open in the external browser, never a view in the app. A new kind of content is a case in `BoardSource.Content` and in `SourceRecord.Content`.
- A statement's `source` puts it in that source's region. A region is never stored: `CanvasRegion` (ErgoLogic) works out its outline from where the source, cards and arrows are, hugging them so it goes in where there's a gap, and `CanvasRegionLayer` draws it. Dragging a source moves its cards too. A card dropped inside a region joins it, and one dropped far from its own leaves. Break Down makes one.
- A `Statement` is `id`, `position` (the box's centre) and `english`. `StatementEditorView` edits one statement of the current board, through `BoardStore`.
- `BoardStore` is how statements and links change (add, update, move, delete, link, unlink, arrange). `Board.map` is the `ArgumentMap` that ErgoLogic's validator, layout and checks take.
- The canvas moves in UIKit (`CanvasBoardView`: pan, pinch, inertia, dragging, arrows), so nothing goes through SwiftUI while it moves. What a box looks like is SwiftUI (`StatementBoxView`), hosted per box, and the bars are SwiftUI (`CanvasBar`). Hosted boxes get no environment from the app: pass anything new in `CanvasBoard.boxContent`. Nothing on the canvas may be laid out from a measured size.
- The statement editor opens out of its box with a UIKit transition (`StatementEditorPresenter`), since SwiftUI's zoom can't find a source view among separately hosted boxes. The editor is hosted too: pass anything new in `CanvasView.editorPresenter`.
- On a view-only board the canvas only pans and zooms, boxes and sources open to read. Hosted boxes learn this from `CanvasBoxModel.isReadOnly`, and `CanvasBoardView.isReadOnly` turns off dragging, connecting and the arrow menu.
