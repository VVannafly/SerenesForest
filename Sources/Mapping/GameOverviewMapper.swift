import Foundation

struct GameOverview {
    let tagline: String
    let story: String

    static func indexed(for games: [Game], pages: [ContentPage]) -> [String: GameOverview] {
        var pagesByURL: [String: ContentPage] = [:]
        for page in pages where pagesByURL[page.url] == nil { pagesByURL[page.url] = page }
        var result: [String: GameOverview] = [:]
        for game in games {
            if let overview = GameOverview(page: pagesByURL[game.sourceURL]) {
                result[game.slug] = overview
            }
        }
        return result
    }

    private static let spinOffEnglish: [String: (String, String)] = [
        "fire-emblem-warriors": ("An action crossover with heroes from across Fire Emblem.", "Rowan and Lianna join familiar heroes in battles against the Chaos Dragon. Explore the story, characters, weapons, and History Mode."),
        "warriors-three-hopes": ("An action game set in the world of Three Houses.", "Shez joins one of Fódlan’s three armies and follows a different path through the war. Browse characters, classes, weapons, and camp activities."),
        "tokyo-mirage-sessions": ("A role-playing crossover set in modern Tokyo.", "Itsuki and the performers of Fortuna Entertainment fight alongside Mirages. Explore chapters, side stories, skills, and equipment.")
    ]

    private static let russian: [String: (String, String)] = [
        "shadow-dragon-and-blade-of-light": ("Первая игра серии Fire Emblem.", "Принц Марф собирает союзников, чтобы освободить Арханею и остановить возродившегося дракона Медеуса."),
        "gaiden": ("Побочная история оригинальной Fire Emblem.", "На разделённом континенте Валентия Альм и Селика идут разными путями, чтобы прекратить войну и противостояние богов."),
        "mystery-of-the-emblem": ("Продолжение первой игры и её обновлённая версия.", "Спустя два года после победы над Медеусом Марф сталкивается с новой угрозой для Архнеи."),
        "genealogy-of-the-holy-war": ("Вторая Fire Emblem для Super Famicom.", "История Югдрала охватывает два поколения героев, начиная с Сигурда и войны королевств."),
        "thracia-776": ("Побочная история Genealogy of the Holy War.", "Изгнанный принц Лиф начинает борьбу за освобождение Ленстера и спасение друзей."),
        "binding-blade": ("Первая портативная Fire Emblem.", "Рой возглавляет армию Ликии, когда на континенте Элибе разгорается новая война с Берном."),
        "blazing-sword": ("Предыстория Binding Blade и первая Fire Emblem на английском языке.", "Эливуд, Гектор и Лин расследуют исчезновение маркиза Ферейского и раскрывают угрозу для Элибе."),
        "the-sacred-stones": ("История близнецов Эйрики и Эфраима.", "Герои путешествуют по Магвелу, чтобы остановить вторжение империи Градо и раскрыть тайну Священных камней."),
        "path-of-radiance": ("Девятая игра серии и первая с трёхмерной графикой.", "На континенте Теллиус наёмник Айк оказывается в центре войны между людьми беорками и лагузами."),
        "radiant-dawn": ("Продолжение Path of Radiance.", "Через три года после войны Теллиус вновь охвачен конфликтом; судьбы новых героев пересекаются с путём Айка."),
        "shadow-dragon": ("Ремейк самой первой Fire Emblem.", "Принц Марф возвращается, чтобы освободить Арханею от Долунской империи и дракона Медеуса."),
        "light-and-shadow": ("Ремейк Mystery of the Emblem.", "После Войны Теней Марф сталкивается с новым кризисом и собирает отряд героев света."),
        "awakening": ("Новая история Fire Emblem для Nintendo 3DS.", "Принц Хром, Робин и Пастыри защищают Илисс от войны и угрозы, связанной с древним драконом."),
        "fire-emblem-fates": ("Три пути одной истории для Nintendo 3DS.", "Коррин оказывается между королевствами Хосидо и Нор, выбирая сторону семьи и судьбу континента."),
        "fire-emblem-echoes-shadows-valentia": ("Ремейк Fire Emblem Gaiden для Nintendo 3DS.", "Альм и Селика пытаются объединить Валентию, разделённую войной и волей богов Милы и Думы."),
        "three-houses": ("Fire Emblem для Nintendo Switch.", "В роли учителя академии Гаррег Мак вы ведёте один из трёх домов и влияете на будущее Фодлана."),
        "engage": ("Fire Emblem для Nintendo Switch.", "На континенте Элиос божественный дракон Алеар объединяет союзников и призывает героев прошлого с помощью колец эмблем."),
        "fortunes-weave": ("Новая Fire Emblem для Nintendo Switch 2.", "История во вселенной Three Houses рассказывает о Геройских играх и новом поколении участников."),
        "fire-emblem-heroes": ("Мобильная Fire Emblem от Nintendo и DeNA.", "В роли призывателя вы собираете героев разных миров и защищаете королевство Аскр."),
        "fire-emblem-warriors": ("Экшен-кроссовер с героями разных игр Fire Emblem.", "Роуэн и Лианна сражаются вместе со знакомыми героями против Дракона Хаоса. В руководстве собраны сюжет, персонажи, оружие и режим «История»."),
        "warriors-three-hopes": ("Экшен во вселенной Three Houses.", "Шез присоединяется к одной из трёх армий Фодлана и проходит иной путь войны. В руководстве есть персонажи, классы, оружие и занятия в лагере."),
        "tokyo-mirage-sessions": ("Ролевая игра-кроссовер в современном Токио.", "Ицуки и артисты Fortuna Entertainment сражаются бок о бок с Миражами. В руководстве есть главы, побочные истории, навыки и снаряжение.")
    ]

    init?(page: ContentPage?) {
        guard let page, !page.plainText.isEmpty else { return nil }
        if let english = Self.spinOffEnglish[page.gameSlug ?? ""] {
            let text = AppText.isRussian ? Self.russian[page.gameSlug ?? ""] ?? english : english
            tagline = text.0
            story = text.1
            return
        }
        if AppText.isRussian, let text = Self.russian[page.gameSlug ?? ""] {
            tagline = text.0
            story = text.1
            return
        }
        let normalized = page.plainText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        let introduction = normalized.components(separatedBy: "\nPlatform\n").first ?? normalized
        let paragraphs = introduction.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard paragraphs.count > 1 else { return nil }
        tagline = paragraphs[1]
        story = paragraphs.dropFirst(2).first {
            !$0.localizedCaseInsensitiveContains("kamagra") &&
            !$0.localizedCaseInsensitiveContains("online apotek")
        } ?? tagline
    }
}

