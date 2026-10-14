import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class RootViewModel {
    var selected: Destination? = .discover
}
