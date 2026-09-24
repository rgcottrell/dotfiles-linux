// Match every query word, prioritizing app names over descriptive metadata.
function normalize(value) {
    return String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

function search(apps, query) {
    const needle = normalize(query).trim();
    const words = needle.split(/\s+/).filter(word => word.length > 0);
    return apps.filter(app => !app.noDisplay && app.name).map(app => {
        const name = normalize(app.name);
        const metadata = normalize([app.genericName, app.comment, (app.keywords || []).join(" ")].join(" "));
        const matches = words.every(word => name.includes(word) || metadata.includes(word));
        const score = !needle ? 0 : name === needle ? 0 : name.startsWith(needle) ? 1
            : name.includes(needle) ? 2 : words.every(word => name.includes(word)) ? 3 : 4;
        return { app: app, matches: matches, score: score };
    }).filter(item => item.matches).sort((a, b) => a.score - b.score
        || a.app.name.localeCompare(b.app.name) || a.app.id.localeCompare(b.app.id))
        .map(item => item.app);
}
