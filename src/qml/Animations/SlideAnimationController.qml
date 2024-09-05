import QtQuick
import TreeLand
import TreeLand.Utils

Item {
    id: root
    visible: false
    readonly property int animationDuration: 400
    readonly property int bounceDuration: 400
    property real refWidth: 1920
    property real refGap: 30
    property real refBounce: 384
    property real bounceFactor: 0.4
    readonly property real refWrap: refWidth + refGap
    readonly property alias running: aniState.running
    readonly property alias viewportPos: aniState.pos
    property var commitWorkspaceId
    readonly property alias pendingWorkspaceId: aniState.destinationId

    QtObject {
        id: aniState
        property real pos
        property bool running: slideAnimation.running || bounceAnimation.running || gestureConnection.running
        property int initialId
        property int destinationId
        property bool needBounce: false
        property real animationInitial: 0
        property real animationDestination: 0
        property int currentDirection: SlideAnimationController.Direction.Left
    }

    readonly property real desktopOffset: Helper.multiTaskViewGesture.desktopOffset

    enum Direction {
        Left,
        Right
    }

    SequentialAnimation {
        id: slideAnimation
        alwaysRunToEnd: false
        NumberAnimation {
            target: aniState
            property: "pos"
            from: aniState.animationInitial
            to: aniState.animationDestination
            duration: animationDuration
            easing.type: Easing.OutExpo
        }
        ScriptAction {
            script: {
                if (aniState.needBounce) {
                    bounceAnimation.start()
                } else {
                    commitWorkspaceId(aniState.destinationId)
                }
            }
        }
    }
    SequentialAnimation {
        id: bounceAnimation
        readonly property real bounceDestination: aniState.animationDestination + (aniState.currentDirection === SlideAnimationController.Direction.Right ? refBounce : -refBounce)
        NumberAnimation {
            target: aniState
            property: "pos"
            from: aniState.animationDestination
            to: bounceAnimation.bounceDestination
            duration: bounceDuration / 2
            easing.type: Easing.InOutExpo
        }
        NumberAnimation {
            target: aniState
            property: "pos"
            from: bounceAnimation.bounceDestination
            to: aniState.animationDestination
            duration: bounceDuration / 2
            easing.type: Easing.InOutExpo
        }
        ScriptAction {
            script: commitWorkspaceId(aniState.destinationId)
        }
    }

    function slideRunning(toId) {
        if (!running) return

        slideAnimation.stop()
        bounceAnimation.stop()
        aniState.animationInitial = aniState.pos
        aniState.animationDestination = refWrap * toId
        aniState.initialId = aniState.pos / refWrap
        aniState.destinationId = toId
        aniState.currentDirection = aniState.animationDestination > aniState.animationInitial ? SlideAnimationController.Direction.Right : SlideAnimationController.Direction.Left
    }
    function slideNormal(fromId, toId) {
        aniState.initialId = fromId
        aniState.destinationId = toId
        aniState.animationInitial = refWrap * fromId
        aniState.animationDestination = refWrap * toId
        aniState.currentDirection = (fromId < toId) ? SlideAnimationController.Direction.Right : SlideAnimationController.Direction.Left
        aniState.pos = aniState.animationInitial
    }

    function slide(fromId, toId) {
        aniState.needBounce = false

        slideRunning(toId)
        slideNormal(fromId, toId)
        slideAnimation.start()
    }

    function bounce(currentWorkspaceId, direction) {
        if (bounceAnimation.running) return
        if (!slideAnimation.running) {
            aniState.initialId = currentWorkspaceId
            aniState.destinationId = currentWorkspaceId
            aniState.currentDirection = direction
            aniState.animationInitial = refWrap * aniState.initialId
            aniState.animationDestination = refWrap * aniState.destinationId
            bounceAnimation.start()
        } else {
            aniState.needBounce = true
        }
    }
    function obstructionGesture (x) {
        var k = 10.0 // control curve bending
        return (bounceFactor / Math.PI) * Math.atan(k * x);
    }

    Connections {
        id: gestureConnection
        target: Helper.multiTaskViewGesture
        property bool running: false
        property bool enable: false
        property bool bounce: false
        property real offset : 0
        property int fromId: 0
        property int toId: 0

        onDesktopOffsetChanged: {
            if (!enable) {
                enable = true
                bounce = false
                fromId = Helper.currentWorkspaceId
                toId = 0
                if (target.desktopOffset > 0) {
                    toId = fromId + 1
                    if (toId >= QmlHelper.workspaceManager.layoutOrder.count) {
                        bounce = true
                    }
                } else if (target.desktopOffset < 0) {
                    toId = fromId - 1
                    if (toId < 0) {
                        bounce = true
                    }
                }

                slideNormal(fromId, toId)
                running = true
            }

            if (enable) {
                offset = bounce ? obstructionGesture(desktopOffset) : desktopOffset
                aniState.pos = aniState.animationInitial + refWrap * offset
            }
        }

        onDesktopOffsetCancelled: {
            if (!enable)
                return

            enable = false
            if (offset === 1 || offset === -1) {
                Helper.currentWorkspaceId = toId
                return
            }

            fromId = Helper.currentWorkspaceId
            toId = 0
            if (offset > bounceFactor / 2) {
                toId = fromId + 1
            } else if (offset <= -bounceFactor / 2) {
                toId = fromId - 1
                if (toId < 0) {
                    return;
                }
            } else {
                [fromId, toId] = [toId, fromId]
            }

            if (toId < QmlHelper.workspaceManager.layoutOrder.count || toId >= 0) {
                slideRunning(toId)
                slideAnimation.start()
                Helper.currentWorkspaceId = toId
            }
            running = false
        }
    }
}