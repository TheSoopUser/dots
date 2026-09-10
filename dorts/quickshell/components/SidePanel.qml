import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    // ─────────────────────────────────────────────
    // Drawer controls
    // ─────────────────────────────────────────────
    // ─────────────────────────────────────────────
    // Calendar helpers
    // ─────────────────────────────────────────────
    // ─────────────────────────────────────────────
    // Weather
    // ─────────────────────────────────────────────
    // ─────────────────────────────────────────────
    // Slider actions
    // ─────────────────────────────────────────────
    // ─────────────────────────────────────────────
    // Reusable glass slider
    // ─────────────────────────────────────────────
    // ─────────────────────────────────────────────
    // Window
    // ─────────────────────────────────────────────

    id: root

    required property var theme
    required property var audio
    required property var brightness
    required property var anchorItem
    property real reveal: 0
    property bool opened: false
    // Calendar state.
    property int calendarYear: (new Date()).getFullYear()
    property int calendarMonth: (new Date()).getMonth()
    property int selectedDay: (new Date()).getDate()
    // Weather state.
    property bool weatherLoading: false
    property bool weatherError: false
    property string weatherCondition: "Loading weather…"
    property string weatherIcon: "☁"
    property int weatherTemp: 0
    property int weatherFeels: 0
    property int weatherHumidity: 0
    property int weatherWind: 0
    property int weatherHigh: 0
    property int weatherLow: 0
    property int weatherRain: 0
    property string weatherUpdated: "—"
    property double lastWeatherFetch: 0

    function glass(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function openPanel() {
        closeAnimation.stop();
        root.opened = true;
        if (!root.visible) {
            root.reveal = 0;
            root.visible = true;
        }
        root.refreshWeather(false);
        openAnimation.restart();
    }

    function closePanel() {
        if (!root.visible)
            return ;

        openAnimation.stop();
        root.opened = false;
        closeAnimation.restart();
    }

    function toggle() {
        if (root.opened)
            root.closePanel();
        else
            root.openPanel();
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function firstWeekday(year, month) {
        return new Date(year, month, 1).getDay();
    }

    function monthName(month) {
        const names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        return names[month];
    }

    function previousMonth() {
        calendarMonth -= 1;
        if (calendarMonth < 0) {
            calendarMonth = 11;
            calendarYear -= 1;
        }
        selectedDay = 0;
    }

    function nextMonth() {
        calendarMonth += 1;
        if (calendarMonth > 11) {
            calendarMonth = 0;
            calendarYear += 1;
        }
        selectedDay = 0;
    }

    function goToday() {
        const now = new Date();
        calendarYear = now.getFullYear();
        calendarMonth = now.getMonth();
        selectedDay = now.getDate();
    }

    function isToday(day) {
        const now = new Date();
        return day > 0 && calendarYear === now.getFullYear() && calendarMonth === now.getMonth() && day === now.getDate();
    }

    function weatherDescription(code) {
        if (code === 0)
            return "Clear sky";

        if (code === 1)
            return "Mostly clear";

        if (code === 2)
            return "Partly cloudy";

        if (code === 3)
            return "Overcast";

        if (code === 45 || code === 48)
            return "Fog";

        if (code === 51 || code === 53 || code === 55)
            return "Drizzle";

        if (code === 56 || code === 57)
            return "Freezing drizzle";

        if (code === 61 || code === 63 || code === 65)
            return "Rain";

        if (code === 66 || code === 67)
            return "Freezing rain";

        if (code === 71 || code === 73 || code === 75 || code === 77)
            return "Snow";

        if (code === 80 || code === 81 || code === 82)
            return "Rain showers";

        if (code === 85 || code === 86)
            return "Snow showers";

        if (code === 95)
            return "Thunderstorms";

        if (code === 96 || code === 99)
            return "Thunderstorms · hail";

        return "Weather";
    }

    function weatherSymbol(code) {
        if (code === 0)
            return "☀";

        if (code === 1)
            return "🌤";

        if (code === 2)
            return "⛅";

        if (code === 3)
            return "☁";

        if (code === 45 || code === 48)
            return "≋";

        if (code >= 51 && code <= 67)
            return "🌧";

        if (code >= 71 && code <= 77)
            return "❄";

        if (code >= 80 && code <= 82)
            return "🌦";

        if (code >= 85 && code <= 86)
            return "🌨";

        if (code >= 95)
            return "⚡";

        return "☁";
    }

    function refreshWeather(force) {
        const now = Date.now();
        // Open-Meteo does not need to be hit every time the panel is toggled.
        if (!force && root.lastWeatherFetch > 0 && now - root.lastWeatherFetch < 5 * 60 * 1000)
            return ;

        if (weatherProcess.running)
            return ;

        root.weatherLoading = true;
        root.weatherError = false;
        weatherProcess.running = true;
    }

    function parseWeather(text) {
        try {
            const data = JSON.parse(text);
            if (!data.current || !data.daily)
                throw new Error("Missing weather fields");

            const current = data.current;
            const daily = data.daily;
            const code = Number(current.weather_code) || 0;
            root.weatherTemp = Math.round(Number(current.temperature_2m) || 0);
            root.weatherFeels = Math.round(Number(current.apparent_temperature) || 0);
            root.weatherHumidity = Math.round(Number(current.relative_humidity_2m) || 0);
            root.weatherWind = Math.round(Number(current.wind_speed_10m) || 0);
            root.weatherHigh = daily.temperature_2m_max ? Math.round(Number(daily.temperature_2m_max[0]) || 0) : 0;
            root.weatherLow = daily.temperature_2m_min ? Math.round(Number(daily.temperature_2m_min[0]) || 0) : 0;
            root.weatherRain = daily.precipitation_probability_max ? Math.round(Number(daily.precipitation_probability_max[0]) || 0) : 0;
            root.weatherCondition = root.weatherDescription(code);
            root.weatherIcon = root.weatherSymbol(code);
            const updateDate = current.time ? new Date(current.time) : new Date();
            root.weatherUpdated = Qt.formatTime(updateDate, "h:mm AP");
            root.weatherLoading = false;
            root.weatherError = false;
            root.lastWeatherFetch = Date.now();
        } catch (error) {
            console.warn("SidePanel weather parse error:", error);
            root.weatherLoading = false;
            root.weatherError = true;
            root.weatherCondition = "Weather unavailable";
        }
    }

    function setVolumePercent(percent) {
        const target = root.clamp(percent, 0, 100);
        const current = Number(root.audio.volumePercent) || 0;
        const delta = (target - current) / 100;
        if (root.audio.muted && target > 0)
            root.audio.toggleMute();

        if (Math.abs(delta) > 0.001)
            root.audio.changeVolume(delta);

    }

    function setBrightnessPercent(percent) {
        const target = Math.round(root.clamp(percent, 1, 100));
        // Your BrightnessService already reads the actual system brightness.
        // brightnessctl provides an exact target for a draggable slider.
        brightnessSetProcess.exec(["brightnessctl", "set", target + "%"]);
    }

    WlrLayershell.namespace: "quickshell-shell"
    // Keep the drawer on the same monitor as the bar.
    screen: root.anchorItem.QSWindow.window.screen
    onVisibleChanged: {
        // Compatibility with code that directly writes visible = true.
        if (root.visible && !root.opened) {
            root.opened = true;
            root.reveal = 0;
            root.refreshWeather(false);
            openAnimation.restart();
        }
        if (!root.visible) {
            root.opened = false;
            root.reveal = 0;
        }
    }
    implicitWidth: 382
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false

    NumberAnimation {
        id: openAnimation

        target: root
        property: "reveal"
        to: 1
        duration: 330
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnimation

        target: root
        property: "reveal"
        to: 0
        duration: 230
        easing.type: Easing.InCubic
        onFinished: {
            if (!root.opened)
                root.visible = false;

        }
    }

    Process {
        id: weatherProcess

        command: ["curl", "-fsSL", "--max-time", "8", "https://api.open-meteo.com/v1/forecast?latitude=30.4213&longitude=-87.2169&current=temperature_2m,apparent_temperature,weather_code,relative_humidity_2m,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=America%2FChicago&forecast_days=1"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.weatherLoading = false;
                root.weatherError = true;
                root.weatherCondition = "Weather unavailable";
            }
        }

        stdout: StdioCollector {
            onStreamFinished: root.parseWeather(this.text)
        }

    }

    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refreshWeather(true)
    }

    Process {
        id: brightnessSetProcess
    }

    anchors {
        left: true
        top: true
        bottom: true
    }

    margins {
        left: 12
        top: root.theme.barHeight + 16
        bottom: 12
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    // Allows Escape to close the drawer.
    Item {
        anchors.fill: parent
        focus: root.opened
        Keys.onEscapePressed: (event) => {
            root.closePanel();
            event.accepted = true;
        }
    }

    Rectangle {
        id: sideSurface

        width: root.width
        height: root.height
        x: -width - 18 + ((width + 18) * root.reveal)
        radius: root.theme.largeRadius
        clip: true
        opacity: 0.55 + (0.45 * root.reveal)
        color: root.glass(root.theme.background, 0.86)
        border.width: 1
        border.color: root.glass(root.theme.borderBright, 0.52)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: root.glass(root.theme.surface, 0.3)
        }

        // Top glass sheen.
        Rectangle {
            height: 120
            radius: parent.radius

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: root.glass(root.theme.accent, 0.075)
                }

                GradientStop {
                    position: 1
                    color: "transparent"
                }

            }

        }

        Flickable {
            id: scroller

            anchors.fill: parent
            anchors.margins: 1
            clip: true
            contentWidth: width
            contentHeight: contentColumn.height + 32
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3500

            Column {
                // ─────────────────────────────────
                // Header + live time/date
                // ─────────────────────────────────
                // ─────────────────────────────────
                // Pensacola weather
                // ─────────────────────────────────
                // ─────────────────────────────────
                // Volume slider
                // ─────────────────────────────────
                // ─────────────────────────────────
                // Brightness slider
                // ─────────────────────────────────
                // ─────────────────────────────────
                // Calendar
                // ─────────────────────────────────

                id: contentColumn

                width: scroller.width - 32
                x: 16
                y: 16
                spacing: 12

                Item {
                    width: parent.width
                    height: 96

                    Column {
                        spacing: 1

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: Qt.formatDateTime(clock.date, "h:mm")
                            color: root.theme.foreground
                            font.pixelSize: 34
                            font.weight: Font.Light
                        }

                        Text {
                            text: Qt.formatDateTime(clock.date, "AP · dddd")
                            color: root.glass(root.theme.foreground, 0.66)
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        Text {
                            text: Qt.formatDateTime(clock.date, "MMMM d, yyyy")
                            color: root.theme.mutedForeground
                            font.pixelSize: 11
                        }

                    }

                    Rectangle {
                        id: closeButton

                        width: 32
                        height: 32
                        radius: width / 2
                        color: closeMouse.containsMouse ? root.glass(root.theme.surfaceHover, 0.92) : root.glass(root.theme.surfaceRaised, 0.54)
                        border.width: 1
                        border.color: closeMouse.containsMouse ? root.glass(root.theme.foreground, 0.1) : "transparent"

                        anchors {
                            right: parent.right
                            top: parent.top
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: root.theme.foreground
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: closeMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.closePanel()
                        }

                    }

                }

                Rectangle {
                    width: parent.width
                    height: 142
                    radius: root.theme.radius
                    color: root.glass(root.theme.surfaceRaised, 0.62)
                    border.width: 1
                    border.color: root.glass(root.theme.border, 0.58)

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Math.max(0, parent.radius - 1)
                        color: root.glass(root.theme.accentMuted, 0.07)
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 13
                        spacing: 10

                        Row {
                            width: parent.width
                            height: 55
                            spacing: 11

                            Text {
                                width: 52
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.weatherLoading ? "…" : root.weatherIcon
                                color: root.theme.foreground
                                font.pixelSize: 34
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Column {
                                width: parent.width - 52 - temperatureBlock.width - 22
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: "Pensacola, FL"
                                    color: root.theme.foreground
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    width: parent.width
                                    text: root.weatherCondition
                                    color: root.weatherError ? root.theme.danger : root.theme.mutedForeground
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.weatherLoading ? "Updating…" : "Updated " + root.weatherUpdated
                                    color: root.theme.subtleForeground
                                    font.pixelSize: 9
                                }

                            }

                            Column {
                                id: temperatureBlock

                                width: 70
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    anchors.right: parent.right
                                    text: root.weatherLoading ? "—" : root.weatherTemp + "°"
                                    color: root.theme.foreground
                                    font.pixelSize: 27
                                    font.weight: Font.Light
                                }

                                Text {
                                    anchors.right: parent.right
                                    text: root.weatherLoading ? "" : "Feels " + root.weatherFeels + "°"
                                    color: root.theme.mutedForeground
                                    font.pixelSize: 9
                                }

                            }

                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.glass(root.theme.borderBright, 0.34)
                        }

                        Row {
                            width: parent.width
                            height: 34

                            Item {
                                width: parent.width / 4
                                height: parent.height

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.weatherHigh + "° / " + root.weatherLow + "°"
                                        color: root.theme.foreground
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "High / low"
                                        color: root.theme.subtleForeground
                                        font.pixelSize: 8
                                    }

                                }

                            }

                            Item {
                                width: parent.width / 4
                                height: parent.height

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.weatherHumidity + "%"
                                        color: root.theme.foreground
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Humidity"
                                        color: root.theme.subtleForeground
                                        font.pixelSize: 8
                                    }

                                }

                            }

                            Item {
                                width: parent.width / 4
                                height: parent.height

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.weatherWind + " mph"
                                        color: root.theme.foreground
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Wind"
                                        color: root.theme.subtleForeground
                                        font.pixelSize: 8
                                    }

                                }

                            }

                            Item {
                                width: parent.width / 4
                                height: parent.height

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.weatherRain + "%"
                                        color: root.theme.foreground
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Rain"
                                        color: root.theme.subtleForeground
                                        font.pixelSize: 8
                                    }

                                }

                            }

                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.MiddleButton
                        onClicked: root.refreshWeather(true)
                    }

                }

                Rectangle {
                    width: parent.width
                    height: 92
                    radius: root.theme.radius
                    color: root.glass(root.theme.surfaceRaised, 0.58)
                    border.width: 1
                    border.color: root.glass(root.theme.border, 0.55)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 7

                        Row {
                            width: parent.width
                            height: 24

                            Text {
                                width: parent.width - muteButton.width - volumePercentText.width - 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.audio.muted ? "Volume · muted" : "Volume"
                                color: root.theme.foreground
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }

                            Text {
                                id: volumePercentText

                                anchors.verticalCenter: parent.verticalCenter
                                text: root.audio.volumePercent + "%"
                                color: root.theme.accent
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            Item {
                                width: 8
                                height: 1
                            }

                            Rectangle {
                                id: muteButton

                                width: 48
                                height: 24
                                radius: height / 2
                                color: muteMouse.containsMouse ? root.glass(root.theme.accentMuted, 0.46) : root.glass(root.theme.background, 0.48)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.audio.muted ? "On" : "Mute"
                                    color: root.audio.muted ? root.theme.accent : root.theme.mutedForeground
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: muteMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.audio.toggleMute()
                                }

                            }

                        }

                        GlassSlider {
                            width: parent.width
                            value: Number(root.audio.volumePercent) || 0
                            onRequested: (value) => {
                                return root.setVolumePercent(value);
                            }
                        }

                    }

                }

                Rectangle {
                    width: parent.width
                    height: 92
                    radius: root.theme.radius
                    color: root.glass(root.theme.surfaceRaised, 0.58)
                    border.width: 1
                    border.color: root.glass(root.theme.border, 0.55)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 7

                        Row {
                            width: parent.width
                            height: 24

                            Text {
                                width: parent.width - brightnessPercentText.width
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Brightness"
                                color: root.theme.foreground
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }

                            Text {
                                id: brightnessPercentText

                                anchors.verticalCenter: parent.verticalCenter
                                text: root.brightness.percent + "%"
                                color: root.theme.accent
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                        }

                        GlassSlider {
                            width: parent.width
                            value: Number(root.brightness.percent) || 0
                            onRequested: (value) => {
                                return root.setBrightnessPercent(value);
                            }
                        }

                    }

                }

                Rectangle {
                    width: parent.width
                    height: 330
                    radius: root.theme.radius
                    color: root.glass(root.theme.surfaceRaised, 0.56)
                    border.width: 1
                    border.color: root.glass(root.theme.border, 0.55)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 9

                        Row {
                            width: parent.width
                            height: 30

                            Rectangle {
                                width: 30
                                height: 30
                                radius: width / 2
                                color: previousMouse.containsMouse ? root.glass(root.theme.surfaceHover, 0.92) : root.glass(root.theme.background, 0.44)

                                Text {
                                    anchors.centerIn: parent
                                    text: "‹"
                                    color: root.theme.foreground
                                    font.pixelSize: 19
                                }

                                MouseArea {
                                    id: previousMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.previousMonth()
                                }

                            }

                            Text {
                                width: parent.width - 100
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.monthName(root.calendarMonth) + " " + root.calendarYear
                                color: root.theme.foreground
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 30
                                height: 30
                                radius: width / 2
                                color: nextMouse.containsMouse ? root.glass(root.theme.surfaceHover, 0.92) : root.glass(root.theme.background, 0.44)

                                Text {
                                    anchors.centerIn: parent
                                    text: "›"
                                    color: root.theme.foreground
                                    font.pixelSize: 19
                                }

                                MouseArea {
                                    id: nextMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.nextMonth()
                                }

                            }

                            Item {
                                width: 10
                                height: 1
                            }

                            Rectangle {
                                width: 30
                                height: 30
                                radius: width / 2
                                color: todayMouse.containsMouse ? root.glass(root.theme.accentMuted, 0.48) : root.glass(root.theme.background, 0.44)

                                Text {
                                    anchors.centerIn: parent
                                    text: "•"
                                    color: root.theme.accent
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    id: todayMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.goToday()
                                }

                            }

                        }

                        Row {
                            width: parent.width
                            height: 20

                            Repeater {
                                model: ["S", "M", "T", "W", "T", "F", "S"]

                                delegate: Text {
                                    required property string modelData

                                    width: parent.width / 7
                                    height: 20
                                    text: modelData
                                    color: root.theme.subtleForeground
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                            }

                        }

                        Grid {
                            width: parent.width
                            height: 224
                            columns: 7
                            rows: 6
                            spacing: 0

                            Repeater {
                                model: 42

                                delegate: Item {
                                    required property int index
                                    property int day: index - root.firstWeekday(root.calendarYear, root.calendarMonth) + 1
                                    property bool valid: day >= 1 && day <= root.daysInMonth(root.calendarYear, root.calendarMonth)

                                    width: parent.width / 7
                                    height: parent.height / 6

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: width / 2
                                        anchors.centerIn: parent
                                        visible: parent.valid
                                        color: root.isToday(parent.day) ? root.glass(root.theme.accentStrong, 0.86) : root.selectedDay === parent.day ? root.glass(root.theme.accentMuted, 0.45) : calendarCellMouse.containsMouse ? root.glass(root.theme.surfaceHover, 0.72) : "transparent"
                                        border.width: root.selectedDay === parent.day && !root.isToday(parent.day) ? 1 : 0
                                        border.color: root.glass(root.theme.accent, 0.5)

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.parent.day
                                            color: root.isToday(parent.parent.day) ? root.theme.background : root.theme.foreground
                                            font.pixelSize: 10
                                            font.weight: root.isToday(parent.parent.day) ? Font.Bold : Font.Normal
                                        }

                                    }

                                    MouseArea {
                                        id: calendarCellMouse

                                        anchors.fill: parent
                                        enabled: parent.valid
                                        hoverEnabled: true
                                        onClicked: root.selectedDay = parent.day
                                    }

                                }

                            }

                        }

                    }

                }

                Item {
                    width: 1
                    height: 4
                }

            }

        }

    }

    component GlassSlider: Item {
        id: slider

        property real value: 0
        property bool interacting: false
        property real dragValue: 0
        readonly property real shownValue: interacting ? dragValue : root.clamp(value, 0, 100)

        signal requested(real value)

        function valueAtX(mouseX) {
            return root.clamp(mouseX / width * 100, 0, 100);
        }

        implicitHeight: 30

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            radius: 4
            color: root.glass(root.theme.background, 0.58)
            border.width: 1
            border.color: root.glass(root.theme.border, 0.5)

            Rectangle {
                width: parent.width * slider.shownValue / 100
                height: parent.height
                radius: parent.radius
                color: root.glass(root.theme.accentStrong, 0.82)

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.glass(root.theme.accent, 0.16)
                }

            }

        }

        Rectangle {
            width: 18
            height: 18
            radius: width / 2
            y: (parent.height - height) / 2
            x: root.clamp(parent.width * slider.shownValue / 100 - width / 2, 0, parent.width - width)
            color: root.theme.foreground
            border.width: 3
            border.color: root.theme.accentStrong
            scale: sliderMouse.pressed ? 1.12 : 1

            Behavior on x {
                enabled: !slider.interacting

                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }

            }

        }

        MouseArea {
            id: sliderMouse

            anchors.fill: parent
            hoverEnabled: true
            onPressed: (mouse) => {
                slider.interacting = true;
                slider.dragValue = slider.valueAtX(mouse.x);
            }
            onPositionChanged: (mouse) => {
                if (pressed)
                    slider.dragValue = slider.valueAtX(mouse.x);

            }
            onReleased: (mouse) => {
                slider.dragValue = slider.valueAtX(mouse.x);
                slider.requested(slider.dragValue);
                slider.interacting = false;
            }
            onCanceled: slider.interacting = false
        }

    }

    mask: Region {
        item: sideSurface
    }

}
