module glui.popup_frame;

import std.traits;
import std.algorithm;

import glui.node;
import glui.tree;
import glui.frame;
import glui.style;
import glui.utils;
import glui.backend;


@safe:


deprecated("popup has been renamed to popupFrame")
alias popup = popupFrame;

deprecated("GluiPopup has been renamed to GluiPopupFrame")
alias GluiPopup = GluiPopupFrame;

alias popupFrame = simpleConstructor!GluiPopupFrame;

/// Spawn a new popup attached to the given tree.
void spawnPopup(LayoutTree* tree, GluiPopupFrame popup) {

    // Set anchor
    popup.anchor = Vector2(
        tree.focusBox.x,
        tree.focusBox.y + tree.focusBox.height
    );

    // Spawn the popup
    tree.queueAction(new PopupNodeAction(popup));
    tree.root.updateSize();

}

/// This is an override of GluiFrame to simplify creating popups: if clicked outside of it, it will disappear from
/// the node tree.
class GluiPopupFrame : GluiFrame {

    mixin defineStyles;

    public {

        /// Position the frame is "anchored" to. A corner of the frame will be chosen to match this position.
        Vector2 anchor;

        /// If true, the popup will not hide if clicked outside.
        bool isProtected;

    }

    this(NodeParams params, GluiNode[] nodes...) {

        super(params, nodes);

    }

    /// Draw the popup using the assigned anchor position.
    void drawAnchored() {

        const rect = Rectangle(
            anchoredStartCorner.tupleof,
            minSize.tupleof
        );

        // Draw the node within the defined rectangle
        draw(rect);

    }

    private void resizeInternal(LayoutTree* tree, Theme theme, Vector2 space) {

        resize(tree, theme, space);

    }

    /// Get start (top-left) corner of the popup if `drawAnchored` is to be used.
    Vector2 anchoredStartCorner() {

        const viewportSize = io.windowSize;

        // This method is very similar to GluiMapSpace.getStartCorner, but simplified to handle the "automatic" case
        // only.

        // Define important points on the screen: center is our anchor, left is the other corner of the popup if we
        // extend it to the top-left, right is the other corner of the popup if we extend it to the bottom-right
        //  x--|    <- left
        //  |  |
        //  |--o--| <- center (anchor)
        //     |  |
        //     |--x <- right
        const left = anchor - minSize;
        const center = anchor;
        const right = anchor + minSize;

        // Horizontal position
        const x

            // Default to extending towards the bottom-right, unless we overflow
            // |=============|
            // |   ↓ center  |
            // |   O------|  |
            // |   |      |  |
            // |   |      |  |
            // |   |------|  |
            // |=============|
            = right.x < viewportSize.x ? center.x

            // But in case we cannot fit the popup, we might need to reverse the direction
            // |=============|          |=============|
            // |             | ↓ right  | ↓ left
            // |        O------>        | <------O    |
            // |        |      |        | |      |    |
            // |        |      |        | |      |    |
            // |        |------|        | |------|    |
            // |=============|          |=============|
            : left.x >= 0 ? left.x

            // However, if we overflow either way, it's best we center the popup on the screen
            : (viewportSize.x - minSize.x) / 2;

        // Do the same for vertical position
        const y
            = right.y < viewportSize.y ? center.y
            : left.y >= 0 ? left.y
            : (viewportSize.y - minSize.y) / 2;

        return Vector2(x, y);

    }

    override protected void drawImpl(Rectangle outer, Rectangle inner) @trusted {

        const mousePressed = tree.io.isReleased(GluiMouseButton.left);

        // Pressed outside!
        if (mousePressed && !isHovered && !isProtected) {

            remove();

        }

        super.drawImpl(outer, inner);

    }

}

/// Tree action displaying a popup.
class PopupNodeAction : TreeAction {

    public {

        /// Popup frames activated by this action.
        GluiPopupFrame[] popups;

    }

    protected {

        /// Safety guard: Do not draw the popup if the tree hasn't resized.
        bool hasResized;

    }

    this(GluiPopupFrame popup) {

        this.startNode = popup;
        this.popups ~= popup;

    }

    override void beforeResize(GluiNode root, Vector2 viewportSize) {

        // Resize the popups
        foreach (popup; popups) {

            popup.resizeInternal(root.tree, root.theme, viewportSize);

        }

        hasResized = true;

    }

    /// Tree drawn, draw the popup now.
    override void afterTree() {

        // Don't draw without a resize
        if (!hasResized) return;

        bool anyPopupVisible;

        // Draw each popup
        foreach (popup; popups) {

            // Ignore popups that are hidden or queued for removal
            if (popup.toRemove) continue;
            if (popup.isHidden) continue;

            popup.drawAnchored();
            anyPopupVisible = true;

        }

        // All popups have been hidden, stop the action
        if (!anyPopupVisible) stop;


    }

    override void afterDraw(GluiNode node, Rectangle space) { }

}
