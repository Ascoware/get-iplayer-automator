// RSRTVArrayController.m
//
// RSRTV stands for Red Sweater Reordering Table View Controller.
//
// Based on code from Apple's DragNDropOutlineView example, which granted 
// unlimited modification and redistribution rights, provided Apple not be held legally liable.
//
// Differences between this file and the original are © 2006 Red Sweater Software.
//
// You are granted a non-exclusive, unlimited license to use, reproduce, modify and 
// redistribute this source code in any form provided that you agree to NOT hold liable 
// Red Sweater Software or Daniel Jalkut for any damages caused by such use.
//

import Cocoa

@objc(RSRTVArrayController)
public class RSRTVArrayController: NSArrayController, NSTableViewDelegate, NSTableViewDataSource {
    @IBOutlet weak var oTableView: NSTableView!

    static let kRSRTVMovedRowsType = NSPasteboard.PasteboardType("com.red-sweater.RSRTVArrayController")
    private var mDraggingEnabled = false

    public override func awakeFromNib() {
        super.awakeFromNib()
        oTableView.registerForDraggedTypes([Self.kRSRTVMovedRowsType])
        oTableView.delegate = self
        draggingEnabled = true
    }

    var draggingEnabled: Bool {
        get { mDraggingEnabled }
        set { mDraggingEnabled = newValue }
    }

    public func tableView(_ tv: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        if draggingEnabled {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: rowIndexes, requiringSecureCoding: false) {
                pboard.declareTypes([Self.kRSRTVMovedRowsType], owner: self)
                pboard.setData(data, forType: Self.kRSRTVMovedRowsType)
            }
                }
        return draggingEnabled
    }

    func tableObjectsSupportCopying() -> Bool {
        guard let objects = arrangedObjects as? [AnyObject] else { return false }
        guard let first = objects.first else { return false }
        return first is NSCopying
    }

    public func tableView(_ tv: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation op: NSTableView.DropOperation) -> NSDragOperation {
        var dragOp: NSDragOperation = []
        if info.draggingSource as? NSTableView === tv {
            dragOp = .move
            if info.draggingSourceOperationMask == .copy && tableObjectsSupportCopying() {
                dragOp = .copy
            }
        }
        tv.setDropRow(row, dropOperation: .above)
        return dragOp
    }

    public  func tableView(_ tv: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation op: NSTableView.DropOperation) -> Bool {
        var row = row
        if row < 0 { row = 0 }
        if info.draggingSource as? NSTableView === tv {
            guard let data = info.draggingPasteboard.data(forType: Self.kRSRTVMovedRowsType),
            let indexSet = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSIndexSet.self, from: data) as IndexSet? else {
                return false
            }
            var rowsAbove = 0
            if info.draggingSourceOperationMask == .copy && tableObjectsSupportCopying() {
                copyObjectsInArrangedObjects(from: indexSet, to: row)
            } else {
                moveObjectsInArrangedObjects(from: indexSet, to: row)
                rowsAbove = rowsAboveRow(row, in: indexSet)
            }
            let range = NSRange(location: row - rowsAbove, length: indexSet.count)
            setSelectionIndexes(IndexSet(integersIn: range.location..<(range.location + range.length)))
            return true
        }
        return false
    }

    func copyObjectsInArrangedObjects(from indexSet: IndexSet, to insertIndex: Int) {
        guard let objects = arrangedObjects as? [AnyObject] else { return }
        var aboveInsertIndexCount = 0
        for copyFromIndex in indexSet.reversed() {
            let copyIndex = copyFromIndex >= insertIndex ? copyFromIndex + aboveInsertIndexCount : copyFromIndex
            if let object = objects[copyIndex] as? NSCopying {
                insert(object.copy(with: nil), atArrangedObjectIndex: insertIndex)
            }
            if copyFromIndex >= insertIndex { aboveInsertIndexCount += 1 }
        }
    }

    func moveObjectsInArrangedObjects(from indexSet: IndexSet, to insertIndex: Int) {
        guard let objects = arrangedObjects as? [AnyObject] else { return }
        var insertIndex = insertIndex
        var aboveInsertIndexCount = 0
        for thisIndex in indexSet.reversed() {
            let removeIndex: Int
            if thisIndex >= insertIndex {
                removeIndex = thisIndex + aboveInsertIndexCount
                aboveInsertIndexCount += 1
            } else {
                removeIndex = thisIndex
                insertIndex -= 1
            }
                let object = objects[removeIndex]
                remove(atArrangedObjectIndex: removeIndex)
                insert(object, atArrangedObjectIndex: insertIndex)
                }
    }

    func rowsAboveRow(_ row: Int, in indexSet: IndexSet) -> Int {
        return indexSet.filter { $0 < row }.count
    }

    public func tableViewColumnDidResize(_ notification: Notification) {
        oTableView.cornerView?.needsDisplay = true
    }
}

