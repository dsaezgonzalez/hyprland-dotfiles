import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property string source
    property color color: "white"
    property int size: 13
    
    width: size
    height: size

    Image {
        id: img
        source: root.source
        sourceSize: Qt.size(root.size, root.size)
        anchors.fill: parent
        visible: false // If it's already white, don't overlay. (SVGs are white)
    }
    
    ColorOverlay {
        anchors.fill: img
        source: img
        color: root.color
        visible: true
    }
}
