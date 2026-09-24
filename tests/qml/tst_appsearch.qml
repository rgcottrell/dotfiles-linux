import QtQuick
import QtTest
import "../../config/quickshell/desktop/AppSearch.js" as AppSearch

TestCase {
    name: "AppSearch"
    property var apps: [
        { id: "browser", name: "Firefox", genericName: "Web Browser", keywords: ["Internet"] },
        { id: "tools", name: "Firefox Tools", comment: "Manage profiles" },
        { id: "docs", name: "Browser Guide", comment: "Help for Firefox" },
        { id: "cafe", name: "Café", keywords: ["Coffee"] },
        { id: "hidden", name: "Firefox Hidden", noDisplay: true }
    ]
    function ids(query) { return AppSearch.search(apps, query).map(app => app.id).join(","); }
    function test_name_matches_rank_above_descriptions() { compare(ids("firefox"), "browser,tools,docs"); }
    function test_all_words_must_match() { compare(ids("web internet"), "browser"); compare(ids("web coffee"), ""); }
    function test_case_accents_and_whitespace() { compare(ids("  CAFE  "), "cafe"); }
    function test_empty_query_is_alphabetical_and_hides_no_display() { compare(ids("  "), "docs,cafe,browser,tools"); }
    function test_punctuation_is_literal() { compare(ids(".*"), ""); }
    function test_does_not_mutate_application_list() {
        AppSearch.search(apps, "firefox");
        compare(apps[0].id, "browser");
        compare(apps.length, 5);
    }
}
