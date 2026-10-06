import Foundation

/// Hardcoded so the widget's team picker works before the first download.
enum NFLTeams {
    static let all: [(abbr: String, name: String)] = [
        ("ARI", "Arizona Cardinals"), ("ATL", "Atlanta Falcons"), ("BAL", "Baltimore Ravens"),
        ("BUF", "Buffalo Bills"), ("CAR", "Carolina Panthers"), ("CHI", "Chicago Bears"),
        ("CIN", "Cincinnati Bengals"), ("CLE", "Cleveland Browns"), ("DAL", "Dallas Cowboys"),
        ("DEN", "Denver Broncos"), ("DET", "Detroit Lions"), ("GB", "Green Bay Packers"),
        ("HOU", "Houston Texans"), ("IND", "Indianapolis Colts"), ("JAX", "Jacksonville Jaguars"),
        ("KC", "Kansas City Chiefs"), ("LA", "Los Angeles Rams"), ("LAC", "Los Angeles Chargers"),
        ("LV", "Las Vegas Raiders"), ("MIA", "Miami Dolphins"), ("MIN", "Minnesota Vikings"),
        ("NE", "New England Patriots"), ("NO", "New Orleans Saints"), ("NYG", "New York Giants"),
        ("NYJ", "New York Jets"), ("PHI", "Philadelphia Eagles"), ("PIT", "Pittsburgh Steelers"),
        ("SEA", "Seattle Seahawks"), ("SF", "San Francisco 49ers"), ("TB", "Tampa Bay Buccaneers"),
        ("TEN", "Tennessee Titans"), ("WAS", "Washington Commanders"),
    ]

    static let abbrs: Set<String> = Set(all.map(\.abbr))

    static func name(for abbr: String) -> String {
        all.first { $0.abbr == abbr }?.name ?? abbr
    }
}
