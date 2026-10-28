pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "effects" as DockEffects
import "AddAppsPlan.js" as Plan

// Picker for adding applications to the Dock: search every installed program,
// tick as many as you like, and sort them into folders before they are added.
//
// The dialog only collects choices. It hands a finished plan (launchers to pin,
// new folder list) to planReady() and does not touch the Dock itself.
Window {
    id: root

    // The Dock's current folders (AppGroupStore.parse result) and pinned launchers.
    property var existingGroups: []
    property var pinnedLaunchers: []
    // When set (opened from a folder's menu), newly ticked apps default to it.
    property string preferredGroupId: ""
    // Replaceable so tests need no desktop database.
    property var appsModel: defaultAppsModel

    property var selected: []
    property var assignments: ({})
    property var newFolders: []
    property bool confirming: false
    property string oneFolderName: ""
    property int folderCounter: 0

    signal planReady(var plan)

    title: i18n("Add Apps to Dock")
    width: 860
    height: 620
    minimumWidth: 680
    minimumHeight: 480
    flags: Qt.Dialog
    color: Kirigami.Theme.backgroundColor

    DockEffects.InstalledAppsModel {
        id: defaultAppsModel
    }

    // ---- state helpers ---------------------------------------------------

    function isInDock(launcher) {
        if (Plan.isPinned(root.pinnedLaunchers, launcher)) {
            return true;
        }
        for (var index = 0; index < root.existingGroups.length; ++index) {
            var members = root.existingGroups[index].members || [];
            for (var m = 0; m < members.length; ++m) {
                if (String(members[m].launcher) === String(launcher)) {
                    return true;
                }
            }
        }
        return false;
    }

    function selectedIndex(launcher) {
        for (var index = 0; index < root.selected.length; ++index) {
            if (root.selected[index].launcher === launcher) {
                return index;
            }
        }
        return -1;
    }

    function toggleApp(app) {
        var index = selectedIndex(app.launcher);
        var next = root.selected.slice();
        var map = Object.assign({}, root.assignments);
        if (index >= 0) {
            next.splice(index, 1);
            delete map[app.launcher];
        } else {
            next.push(app);
            if (root.preferredGroupId.length > 0) {
                map[app.launcher] = "group:" + root.preferredGroupId;
            }
        }
        root.selected = next;
        root.assignments = map;
    }

    function assign(launcher, target) {
        var map = Object.assign({}, root.assignments);
        if (target) {
            map[launcher] = target;
        } else {
            delete map[launcher];
        }
        root.assignments = map;
    }

    function addFolder(name) {
        root.folderCounter += 1;
        var key = "f" + root.folderCounter;
        var folders = root.newFolders.slice();
        folders.push({
            key: key,
            name: name || i18n("Group %1", root.folderCounter)
        });
        root.newFolders = folders;
        return key;
    }

    function renameFolder(key, name) {
        var folders = root.newFolders.slice();
        for (var index = 0; index < folders.length; ++index) {
            if (folders[index].key === key) {
                folders[index] = { key: key, name: name };
            }
        }
        root.newFolders = folders;
    }

    function removeFolder(key) {
        var folders = [];
        for (var index = 0; index < root.newFolders.length; ++index) {
            if (root.newFolders[index].key !== key) {
                folders.push(root.newFolders[index]);
            }
        }
        var map = Object.assign({}, root.assignments);
        for (var launcher in map) {
            if (map[launcher] === "new:" + key) {
                delete map[launcher];
            }
        }
        root.newFolders = folders;
        root.assignments = map;
    }

    function allInNewFolder() {
        var key = addFolder("");
        root.assignments = Plan.allInOneFolder(root.selected, key);
    }

    // Choices offered in each selected app's folder box.
    readonly property var folderChoices: {
        var choices = [{ text: i18n("Not in a group"), value: "" }];
        for (var n = 0; n < root.newFolders.length; ++n) {
            choices.push({
                text: String(root.newFolders[n].name || "").trim()
                    || i18n("Group"),
                value: "new:" + root.newFolders[n].key
            });
        }
        for (var g = 0; g < root.existingGroups.length; ++g) {
            choices.push({
                text: i18n("%1 (in Dock)", root.existingGroups[g].name),
                value: "group:" + root.existingGroups[g].id
            });
        }
        return choices;
    }

    function reset() {
        root.selected = [];
        root.assignments = ({});
        root.newFolders = [];
        root.folderCounter = 0;
        root.confirming = false;
        root.oneFolderName = i18n("New Group");
        searchField.text = "";
        root.appsModel.filter = "";
    }

    function finish() {
        var plan = Plan.buildPlan(root.selected, root.assignments,
            root.newFolders, root.existingGroups, root.pinnedLaunchers);
        root.confirming = false;
        root.planReady(plan);
        root.visible = false;
    }

    // With several apps and no folder chosen yet, ask whether they should all
    // go into one folder.
    function requestAdd() {
        if (root.selected.length === 0) {
            return;
        }
        if (root.selected.length >= 2
                && !Plan.hasFolderChoice(root.selected, root.assignments)) {
            root.confirming = true;
            return;
        }
        finish();
    }

    function confirmOneFolder() {
        var key = addFolder(root.oneFolderName.trim()
            || i18n("New Group"));
        root.assignments = Plan.allInOneFolder(root.selected, key);
        finish();
    }

    onVisibleChanged: {
        if (visible) {
            reset();
            searchField.forceActiveFocus();
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.confirming) {
                root.confirming = false;
            } else {
                root.visible = false;
            }
        }
    }

    // ---- layout ----------------------------------------------------------

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.SearchField {
            id: searchField

            Layout.fillWidth: true
            placeholderText: i18n("Search installed apps…")
            onTextChanged: root.appsModel.filter = text
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing

            // Installed apps
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: i18n("Installed apps (%1)", root.appsModel.count)
                    font.bold: true
                }

                ListView {
                    id: appList

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.appsModel
                    reuseItems: false
                    QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                    delegate: QQC2.ItemDelegate {
                        id: appRow

                        required property var model

                        readonly property string launcher: String(model.launcherUrl)
                        readonly property bool inDock: root.isInDock(launcher)
                        readonly property bool picked:
                            root.selectedIndex(launcher) >= 0

                        width: ListView.view.width
                        enabled: !inDock
                        highlighted: picked
                        onClicked: root.toggleApp({
                            launcher: launcher,
                            name: String(model.name),
                            icon: String(model.icon),
                            appId: String(model.storageId)
                        })

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC2.CheckBox {
                                checked: appRow.picked || appRow.inDock
                                enabled: false
                            }
                            Kirigami.Icon {
                                source: String(appRow.model.icon)
                                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: String(appRow.model.name)
                                    elide: Text.ElideRight
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: appRow.inDock
                                        ? i18n("Already in Dock")
                                        : String(appRow.model.genericName
                                            || appRow.model.comment || "")
                                    opacity: 0.65
                                    font: Kirigami.Theme.smallFont
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit * 4
                        visible: appList.count === 0
                        text: i18n("No apps found")
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillHeight: true
            }

            // Selection and folders
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: i18n("To add (%1)", root.selected.length)
                        font.bold: true
                    }
                    QQC2.Button {
                        text: i18n("New Group")
                        icon.name: "folder-new"
                        onClicked: root.addFolder("")
                    }
                    QQC2.Button {
                        text: i18n("All in One Group")
                        icon.name: "folder"
                        enabled: root.selected.length >= 2
                        onClicked: root.allInNewFolder()
                    }
                }

                // New folders
                Repeater {
                    model: root.newFolders

                    delegate: RowLayout {
                        id: folderRow

                        required property var modelData

                        Layout.fillWidth: true

                        Kirigami.Icon {
                            source: "folder"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        QQC2.TextField {
                            Layout.fillWidth: true
                            text: String(folderRow.modelData.name)
                            placeholderText: i18n("Group name")
                            onEditingFinished: root.renameFolder(
                                folderRow.modelData.key, text)
                        }
                        QQC2.ToolButton {
                            icon.name: "edit-delete"
                            onClicked: root.removeFolder(folderRow.modelData.key)
                            QQC2.ToolTip.text: i18n("Remove group")
                            QQC2.ToolTip.visible: hovered
                        }
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    visible: root.newFolders.length > 0
                    wrapMode: Text.WordWrap
                    opacity: 0.65
                    font: Kirigami.Theme.smallFont
                    text: i18n("A group needs at least two apps. With only one, the app is added on its own.")
                }

                ListView {
                    id: selectedList

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.selected
                    QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                    delegate: RowLayout {
                        id: pickedRow

                        required property var modelData

                        width: ListView.view.width
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: String(pickedRow.modelData.icon)
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: String(pickedRow.modelData.name)
                            elide: Text.ElideRight
                        }
                        QQC2.ComboBox {
                            id: folderBox

                            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                            model: root.folderChoices
                            textRole: "text"
                            valueRole: "value"
                            currentIndex: Math.max(0, indexOfValue(
                                root.assignments[pickedRow.modelData.launcher] || ""))
                            onActivated: root.assign(
                                pickedRow.modelData.launcher, currentValue)
                        }
                        QQC2.ToolButton {
                            icon.name: "list-remove"
                            onClicked: root.toggleApp(pickedRow.modelData)
                            QQC2.ToolTip.text: i18n("Remove from selection")
                            QQC2.ToolTip.visible: hovered
                        }
                    }

                    Kirigami.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit * 2
                        visible: root.selected.length === 0
                        text: i18n("Tick apps on the left to add them")
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }
            QQC2.Button {
                text: i18n("Cancel")
                onClicked: root.visible = false
            }
            QQC2.Button {
                id: addButton

                text: root.selected.length > 1
                    ? i18n("Add %1 Apps", root.selected.length)
                    : i18n("Add to Dock")
                icon.name: "list-add"
                highlighted: true
                enabled: root.selected.length > 0
                onClicked: root.requestAdd()
            }
        }
    }

    // ---- "all in one folder?" question ------------------------------------

    Rectangle {
        anchors.fill: parent
        visible: root.confirming
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - Kirigami.Units.gridUnit * 4,
                Kirigami.Units.gridUnit * 28)
            height: questionColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.backgroundColor
            border.color: Kirigami.Theme.separatorColor

            ColumnLayout {
                id: questionColumn

                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.bold: true
                    text: i18n("Put all %1 apps into one group?", root.selected.length)
                }
                QQC2.TextField {
                    id: oneFolderField

                    Layout.fillWidth: true
                    text: root.oneFolderName
                    placeholderText: i18n("Group name")
                    onTextEdited: root.oneFolderName = text
                    onAccepted: root.confirmOneFolder()
                }
                RowLayout {
                    Layout.fillWidth: true

                    QQC2.Button {
                        text: i18n("Back")
                        onClicked: root.confirming = false
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    QQC2.Button {
                        text: i18n("No, Add Separately")
                        onClicked: root.finish()
                    }
                    QQC2.Button {
                        text: i18n("Yes, One Group")
                        highlighted: true
                        onClicked: root.confirmOneFolder()
                    }
                }
            }
        }
    }
}
