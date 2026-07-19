/*
    SPDX-FileCopyrightText: 2020 Aleix Pol Gonzalez <aleixpol@kde.org>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

PipeWire.PipeWireSourceItem {
    id: root

    property var windowId
    readonly property bool hasThumbnail: root.ready

    anchors.fill: parent
    nodeId: screencastingRequest.nodeId

    TaskManager.ScreencastingRequest {
        id: screencastingRequest

        uuid: root.windowId
    }
}
