import QtQuick
import QtTest
import "../../config/quickshell/desktop"

TestCase {
    id: test
    name: "NotificationCard"
    when: windowShown
    visible: true
    width: 600; height: 600
    Theme { id: testTheme }
    QtObject {
        id: action
        property string identifier: "open"
        property string text: "Open"
        property int invocations: 0
        function invoke() { invocations++; }
    }
    QtObject {
        id: notice
        property int urgency: 1
        property int expireTimeout: 150
        property string appName: "Test app"
        property string summary: "Test notice"
        property string body: "A message"
        property var actions: [action]
        property int expirations: 0
        property int dismissals: 0
        function expire() { expirations++; }
        function dismiss() { dismissals++; }
    }
    NotificationCard {
        id: card
        x: 50; y: 50; width: 380
        theme: testTheme
        notification: notice
        critical: notice.urgency === 2
    }
    function init() {
        card.visible = false;
        notice.urgency = 1;
        notice.expireTimeout = 150;
        notice.body = "A message";
        notice.expirations = 0;
        notice.dismissals = 0;
        action.invocations = 0;
        mouseMove(test, 590, 590);
    }
    function cleanup() { card.visible = false; }
    function test_expiry() {
        card.visible = true;
        tryCompare(notice, "expirations", 1, 1000);
        compare(notice.dismissals, 0);
    }
    function test_critical_never_auto_expires() {
        notice.urgency = 2;
        card.visible = true;
        wait(250);
        compare(notice.expirations, 0);
    }
    function test_zero_timeout_is_sticky() {
        notice.expireTimeout = 0;
        card.visible = true;
        wait(250);
        compare(notice.expirations, 0);
    }
    function test_queued_card_gets_full_lifetime() {
        wait(250);
        compare(notice.expirations, 0);
        card.visible = true;
        wait(50);
        compare(notice.expirations, 0);
        tryCompare(notice, "expirations", 1, 1000);
    }
    function test_hover_pauses_expiry() {
        card.visible = true;
        mouseMove(card, 20, 20);
        wait(250);
        compare(notice.expirations, 0);
        mouseMove(test, 590, 590);
        tryCompare(notice, "expirations", 1, 1000);
    }
    function test_replacement_refreshes_lifetime() {
        card.visible = true;
        wait(100);
        notice.body = "Replacement message";
        wait(100);
        compare(notice.expirations, 0);
        tryCompare(notice, "expirations", 1, 1000);
    }
    function test_click_dismisses() {
        card.visible = true;
        mouseClick(findChild(card, "dismissArea"), 20, 50);
        compare(notice.dismissals, 1);
    }
    function test_action_invokes_without_background_dismissal() {
        card.visible = true;
        const button = findChild(card, "notificationAction");
        verify(button !== null);
        mouseClick(button);
        compare(action.invocations, 1);
        compare(notice.dismissals, 0);
    }
}
