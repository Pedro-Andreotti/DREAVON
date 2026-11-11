import QtQuick
import "../package/contents/ui/timeparse.js" as TP

// Testes do leitor de prazos e de iCalendar. Rode: tests/run.sh (sai com código 1 se algo falhar).
Item {
    property int failures: 0
    function check(name, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want)
        if (!ok) { failures++; console.log("FALHOU " + name + ": obtido " + JSON.stringify(got) + " esperado " + JSON.stringify(want)) }
        else console.log("ok " + name)
    }
    function at(y, m, d, h, mi) { return new Date(y, m - 1, d, h || 0, mi || 0).getTime() }

    Component.onCompleted: {
        // Quarta-feira, 11/11/2026 10:00
        const now = at(2026, 11, 11, 10, 0)

        let r = TP.parseWhen("ligar para o João às 15:30", now)
        check("hoje às 15:30", [r.text, r.due], ["ligar para o João", at(2026, 11, 11, 15, 30)])
        r = TP.parseWhen("tomar remédio em 20 min", now)
        check("em 20 min", [r.text, r.due], ["tomar remédio", now + 20 * 60000])
        r = TP.parseWhen("reunião amanhã 9h", now)
        check("amanhã 9h", [r.text, r.due], ["reunião", at(2026, 11, 12, 9, 0)])
        r = TP.parseWhen("dentista sexta 14h30", now)
        check("sexta 14h30", [r.text, r.due], ["dentista", at(2026, 11, 13, 14, 30)])
        r = TP.parseWhen("academia às 8", now)
        check("hora já passou vira amanhã", [r.text, r.due], ["academia", at(2026, 11, 12, 8, 0)])
        r = TP.parseWhen("pagar conta quarta", now)
        check("mesmo dia da semana vai para a próxima", [r.text, r.due], ["pagar conta", at(2026, 11, 18, 9, 0)])
        r = TP.parseWhen("comprar 3 cafés", now)
        check("número solto não é horário", [r.text, r.due], ["comprar 3 cafés", 0])
        r = TP.parseWhen("reunião 25:99", now)
        check("hora inválida", r.due, 0)

        check("formato hoje", TP.formatDue(at(2026, 11, 11, 15, 30), now), "hoje 15:30")
        check("formato amanhã", TP.formatDue(at(2026, 11, 12, 9, 0), now), "amanhã 09:00")
        check("formato semana", TP.formatDue(at(2026, 11, 13, 14, 30), now), "sex 14:30")
        check("formato data", TP.formatDue(at(2026, 12, 2, 8, 5), now), "02/12 08:05")

        const ics = [
            "BEGIN:VCALENDAR",
            "BEGIN:VEVENT", "UID:a", "SUMMARY:Reunião\\, semanal", "DTSTART;TZID=America/Sao_Paulo:20261109T140000",
            "DTEND;TZID=America/Sao_Paulo:20261109T150000", "RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4", "EXDATE:20261111T140000", "END:VEVENT",
            "BEGIN:VEVENT", "UID:b", "SUMMARY:Aniversário", "DTSTART;VALUE=DATE:20261112", "END:VEVENT",
            "BEGIN:VEVENT", "UID:c", "SUMMARY:Cancelado", "STATUS:CANCELLED", "DTSTART:20261112T120000", "END:VEVENT",
            "BEGIN:VEVENT", "UID:d", "SUMMARY:Dia", "DTSTART:20261110T200000Z", "DTEND:20261110T210000Z", "END:VEVENT",
            "BEGIN:VEVENT", "UID:e", "SUMMARY:Mensal", "DTSTART:20260131T090000", "RRULE:FREQ=MONTHLY", "END:VEVENT",
            "END:VCALENDAR"].join("\r\n")
        const events = TP.parseIcs(ics, at(2026, 11, 1), at(2026, 12, 31, 23, 59), "teste")
        const names = events.map(e => e.title + "@" + new Date(e.start).toISOString().slice(0, 10) + (e.allDay ? "*" : ""))
        // Semanal seg/qua com COUNT=4: 9/11, 11/11 (excluído), 16/11, 18/11. Mensal no dia 31: só meses com dia 31.
        check("eventos", names, ["Reunião, semanal@2026-11-09", "Dia@2026-11-10", "Aniversário@2026-11-12*", "Reunião, semanal@2026-11-16", "Reunião, semanal@2026-11-18", "Mensal@2026-12-31"])
        check("duração", events[0].end - events[0].start, 3600000)

        console.log(failures === 0 ? "TODOS OS TESTES PASSARAM" : failures + " FALHA(S)")
        Qt.exit(failures === 0 ? 0 : 1)
    }
}
