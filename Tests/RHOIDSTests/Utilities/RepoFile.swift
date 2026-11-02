import Foundation

/// Copies of repository files that tests read as data.
///
/// The RHOIDSTests target copies these files into its bundle under `RepoFiles/`
/// (see `project.yml`). Xcode Cloud runs tests on a host without the repository,
/// so tests read the bundled copies instead of walking up from `#filePath`.
enum RepoFile {
    enum LookupError: Error, CustomStringConvertible {
        case notBundled(String)

        var description: String {
            switch self {
            case .notBundled(let path):
                "\(path) is not copied into the test bundle. Add it to the RHOIDSTests sources in project.yml."
            }
        }
    }

    /// Returns the bundled copy of `relativePath`, a path from the repository root.
    static func url(_ relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LookupError.notBundled(relativePath)
        }
        return url
    }

    /// Root of the bundled copies, laid out like the repository.
    static var root: URL {
        let bundle = Bundle(for: BundleToken.self)
        return (bundle.resourceURL ?? bundle.bundleURL)
            .appendingPathComponent("RepoFiles", isDirectory: true)
    }
}

private final class BundleToken {}
