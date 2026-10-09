// PetState mirrors `enum state` in upstream xpet.h.
// NOTE: upstream X11 uses Y-down (S = +y). AppKit uses Y-up,
// so N/S semantics are flipped at the findOctant boundary —
// the enum itself stays identical.

public enum PetState: Int, CaseIterable, Equatable {
    case sleeping = 0
    case idle
    case n, s, e, w
    case nw, ne, sw, se
    case dragged
    case happy

    /// Directory name under Resources/pets/<pet>/<state>/ (matches upstream).
    public var assetDirectoryName: String {
        switch self {
        case .sleeping: return "sleeping"
        case .idle: return "idle"
        case .n: return "walk_north"
        case .s: return "walk_south"
        case .e: return "walk_east"
        case .w: return "walk_west"
        case .nw: return "walk_northwest"
        case .ne: return "walk_northeast"
        case .sw: return "walk_southwest"
        case .se: return "walk_southeast"
        case .dragged: return "dragged"
        case .happy: return "happy"
        }
    }

    public var isWalking: Bool {
        switch self {
        case .n, .s, .e, .w, .nw, .ne, .sw, .se: return true
        default: return false
        }
    }
}
