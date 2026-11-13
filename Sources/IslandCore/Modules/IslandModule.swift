import Combine
import SwiftUI

public enum CompactPosition {
    case leading
    case trailing
}

@MainActor
public protocol IslandModule: ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    var id: String { get }
    var title: String { get }
    var priority: Int { get }
    var isActive: Bool { get }

    func compactView(for position: CompactPosition) -> AnyView
    func expandedView() -> AnyView
    func start()
    func stop()
}
