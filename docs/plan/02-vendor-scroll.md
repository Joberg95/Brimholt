# 02 - Vendor list keeps its scroll

**Effort:** S

## Request
Selling an item snaps the vendor list back to the top. Keep the scroll position so the layout
does not jump.

## Today
`open_trade()` in `game/ui/npc_dialogs.gd` rebuilds the whole dialog, including a new
`ScrollContainer`, after every buy or sell, so the scroll resets to 0. The craft dialog's recipe
list works the same way.

## Steps
1. Keep the trade scroll offset in a member (`_trade_scroll: int`). Save it from
   `scroll.scroll_vertical` before a buy or sell rebuilds the dialog; reset it when a different
   NPC is opened.
2. After the rebuild, restore it once the container has its size
   (`scroll.set_deferred("scroll_vertical", ...)`, or after one `process_frame`).
3. Same for the craft dialog's recipe list.
4. Only if it stays simple: update the changed row and the gold label in place instead of
   rebuilding the dialog.

## Tests
Visual test: open a vendor, scroll down, sell, assert `scroll_vertical` is unchanged.

## Done when
Buying or selling never moves the list.
