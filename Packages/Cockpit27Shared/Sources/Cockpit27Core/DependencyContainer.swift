import Foundation

/// Thread-safe lightweight Dependency Injection Container for ECS Systems & ViewModels
@MainActor
public final class DependencyContainer {
    public static let shared = DependencyContainer()
    
    private var services: [String: Any] = [:]
    
    private init() {
        // Register default fallback services
        register(Audio27ServiceProtocol.self, service: DefaultAudio27Service())
        register(Cockpit27TelemetryProtocol.self, service: DefaultCockpit27TelemetryService())
    }
    
    /// Register a service implementation for a given protocol type
    public func register<T>(_ serviceType: T.Type, service: T) {
        let key = String(reflecting: serviceType)
        services[key] = service
    }
    
    /// Resolve a service implementation for a given protocol type
    public func resolve<T>(_ serviceType: T.Type) -> T {
        let key = String(reflecting: serviceType)
        guard let service = services[key] as? T else {
            fatalError("DependencyContainer: No registered service for \(key)")
        }
        return service
    }
    
    /// Try resolving an optional service implementation
    public func tryResolve<T>(_ serviceType: T.Type) -> T? {
        let key = String(reflecting: serviceType)
        return services[key] as? T
    }
}
