import QtQuick
import QtQuick.Shapes

// One bar segment hanging from the top screen edge: a flat translucent blade sized to its content.
// `leftBlade` / `rightBlade` slant that end: the top corner points out and the bottom is cut back
// by Theme.blade. A side without a blade is flat and meant to sit on the screen edge, so it gets no border.
// Children land in `body`, inset past the blades, so `anchors.centerIn: parent` stays clear of the tips.
Item {
    id: root

    required property Item content
    property bool leftBlade: false
    property bool rightBlade: false
    // Slash fins trail outward from a blade; the bar turns them off where space runs out.
    property bool leftFins: leftBlade
    property bool rightFins: rightBlade
    readonly property int padding: 6
    readonly property int leftInset: padding + (leftBlade ? Theme.blade : 0)
    readonly property int rightInset: padding + (rightBlade ? Theme.blade : 0)
    // Bottom corners; the top edge always spans the full width.
    readonly property real bottomLeft: leftBlade ? Theme.blade : 0
    readonly property real bottomRight: width - (rightBlade ? Theme.blade : 0)

    default property alias data: body.data

    y: 0
    width: Math.ceil(content.implicitWidth) + leftInset + rightInset
    height: Theme.barHeight

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Fill
        ShapePath {
            strokeWidth: -1
            fillColor: Theme.surface
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.bottomRight; y: root.height }
            PathLine { x: root.bottomLeft; y: root.height }
            PathLine { x: 0; y: 0 }
        }

        // Bottom edge
        ShapePath {
            strokeWidth: 1
            strokeColor: Theme.edge
            fillColor: "transparent"
            startX: root.bottomLeft
            startY: root.height - 0.5
            PathLine { x: root.bottomRight; y: root.height - 0.5 }
        }

        // Blade edges: brighter, so the cut reads as the island's end
        ShapePath {
            strokeWidth: 1
            strokeColor: root.leftBlade ? Theme.edgeStrong : "transparent"
            fillColor: "transparent"
            startX: 0.5
            startY: 0
            PathLine { x: root.bottomLeft + 0.5; y: root.height - 0.5 }
        }
        ShapePath {
            strokeWidth: 1
            strokeColor: root.rightBlade ? Theme.edgeStrong : "transparent"
            fillColor: "transparent"
            startX: root.width - 0.5
            startY: 0
            PathLine { x: root.bottomRight - 0.5; y: root.height - 0.5 }
        }
    }

    // Decorative fins outside the island's width, so the bar's input mask never covers them.
    // Each fin is one solid parallelogram parallel to the blade edge, hanging from the top; the last
    // one gets a triangular cap on its outer edge so the set tapers to a point.
    readonly property var fins: {
        const out = [];
        let d = Theme.finLead;
        Theme.finGroups.forEach((n, g) => {
            const w = n * Theme.finWidth;
            const last = g === Theme.finGroups.length - 1;
            out.push({ d: d, w: w, h: Theme.barHeight * Theme.finHeights[g], cap: last ? Theme.finCap : 0 });
            d += w + Theme.finGroupGap;
        });
        return out;
    }

    Repeater {
        model: root.fins.length * 2

        Shape {
            id: fin
            required property int index
            readonly property bool isRight: index % 2 === 1
            readonly property var f: root.fins[Math.floor(index / 2)]
            // Mirror: +1 extends right from the top-right corner, -1 left from the top-left corner.
            readonly property real dir: isRight ? 1 : -1
            readonly property real x0: isRight ? root.width : 0
            readonly property real slant: Theme.blade * f.h / Theme.barHeight

            visible: isRight ? root.rightFins : root.leftFins
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillColor: Theme.violet
                startX: fin.x0 + fin.dir * fin.f.d
                startY: 0
                PathLine { x: fin.x0 + fin.dir * (fin.f.d + fin.f.w); y: 0 }
                // Outer edge midpoint: on the edge for plain blades, pushed out into the cap's tip on the last.
                PathLine { x: fin.x0 + fin.dir * (fin.f.d + fin.f.w - fin.slant / 2 + fin.f.cap); y: fin.f.h / 2 }
                PathLine { x: fin.x0 + fin.dir * (fin.f.d + fin.f.w - fin.slant); y: fin.f.h }
                PathLine { x: fin.x0 + fin.dir * (fin.f.d - fin.slant); y: fin.f.h }
                PathLine { x: fin.x0 + fin.dir * fin.f.d; y: 0 }
            }
        }
    }

    Item {
        id: body
        x: root.leftInset
        width: root.width - root.leftInset - root.rightInset
        height: root.height
    }
}
