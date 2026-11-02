import SwiftUI
import UIKit
import Observation
import os

/// Renders options into images using hidden windows behind the app's own.
///
/// A separate window is the only full isolation: inside our view hierarchy an option's
/// NavigationStack adopts our navigation controller (its title and toolbar leak into ours)
/// and its TabView draws no bar. In its own window it gets real bars and the scene's real
/// safe area (the 84 pt rail), exactly as it will look when opened.
///
/// Images are cached in memory and on disk (keyed by build, so a new build re-renders).
@MainActor
@Observable
final class ThumbnailRenderer {
    static let shared = ThumbnailRenderer()

    private(set) var images: [String: UIImage] = [:]
    /// Keys whose last render produced nothing. The card shows a retry placeholder.
    private(set) var failed: Set<String> = []

    private struct Job {
        let key: String
        let lab: LabID
        let values: [String: String]
        let pose: PreviewPose
        let scheme: ColorScheme
    }

    /// Waiting jobs, first in first out: the cards that appeared first render first.
    @ObservationIgnored private var queue: [Job] = []
    /// Jobs a worker has taken but not finished. A repeat request for one of these is a no-op.
    @ObservationIgnored private var inFlight: Set<String> = []
    /// Window slots with no worker on them. Each worker keeps its slot (and window) for life.
    @ObservationIgnored private var freeSlots: Set<Int> = [0, 1]
    @ObservationIgnored private var windows: [Int: UIWindow] = [:]
    @ObservationIgnored private let log = Logger(subsystem: "duolab", category: "thumbnails")
    @ObservationIgnored private let directory: URL = {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let stamp = (try? Bundle.main.executableURL?.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            .map { String(Int($0.timeIntervalSince1970)) } ?? "0"
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "thumbnails-\(build)-\(stamp)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func key(lab: LabID, values: [String: String], pose: PreviewPose, scheme: ColorScheme) -> String {
        "\(pose.rawValue)-\(scheme == .dark ? "dark" : "light")|" + KnobState(lab: lab, values: values).variantKey
    }

    func request(lab: LabID, values: [String: String], pose: PreviewPose, scheme: ColorScheme) {
        let key = Self.key(lab: lab, values: values, pose: pose, scheme: scheme)
        guard images[key] == nil, !failed.contains(key), !inFlight.contains(key),
              !queue.contains(where: { $0.key == key }) else { return }
        if let cached = loadFromDisk(key) {
            images[key] = cached
            return
        }
        queue.append(Job(key: key, lab: lab, values: values, pose: pose, scheme: scheme))
        log.debug("queued \(key, privacy: .public) (\(self.queue.count) waiting)")
        startWorkers()
    }

    /// A card scrolled away: if its job has not started, let the cards still on screen go first.
    func demote(_ key: String) {
        guard let index = queue.firstIndex(where: { $0.key == key }), index < queue.count - 1 else { return }
        queue.append(queue.remove(at: index))
    }

    /// Clears a failure (or a stuck wait) and puts the job at the front of the line.
    func retry(lab: LabID, values: [String: String], pose: PreviewPose, scheme: ColorScheme) {
        let key = Self.key(lab: lab, values: values, pose: pose, scheme: scheme)
        failed.remove(key)
        guard images[key] == nil, !inFlight.contains(key) else { return }
        queue.removeAll { $0.key == key }
        queue.insert(Job(key: key, lab: lab, values: values, pose: pose, scheme: scheme), at: 0)
        log.debug("retry \(key, privacy: .public)")
        startWorkers()
    }

    private func startWorkers() {
        while !queue.isEmpty, let slot = freeSlots.min() {
            freeSlots.remove(slot)
            Task { await work(slot: slot) }
        }
    }

    private func work(slot: Int) async {
        while !queue.isEmpty {
            let job = queue.removeFirst()
            guard images[job.key] == nil, !inFlight.contains(job.key) else { continue }
            inFlight.insert(job.key)
            let start = ContinuousClock.now
            let image = await render(job, slot: slot)
            inFlight.remove(job.key)
            if let image {
                images[job.key] = image
                saveToDisk(image, key: job.key)
                log.debug("rendered \(job.key, privacy: .public) slot \(slot) in \(ContinuousClock.now - start)")
            } else {
                failed.insert(job.key)
                log.error("render failed \(job.key, privacy: .public) slot \(slot)")
            }
        }
        windows[slot]?.isHidden = true
        freeSlots.insert(slot)
    }

    private func render(_ job: Job, slot: Int) async -> UIImage? {
        guard let window = window(slot) else { return nil }
        let content = LabContent(lab: job.lab, state: KnobState(lab: job.lab, values: job.values))
            .environment(\.simulatedFold, job.pose.fold)
            .environment(\.isThumbnail, true)
        let host = UIHostingController(rootView: AnyView(content))
        // Only override the size class for the display we are not on; overriding the current
        // one changes how TabView adapts (it picked a sidebar instead of the Duo's bar).
        let current = window.windowScene?.traitCollection.horizontalSizeClass
        let wanted: UIUserInterfaceSizeClass = job.pose == .open ? .regular : .compact
        // Exception: a hidden window reads as compact to TabView's sidebar logic, so the
        // sidebar option needs regular forced, or its miniature shows the upright bar instead.
        let sidebar = job.lab == .tabBar && job.values["placement"] == "sidebar" && job.pose == .open
        if current != wanted || sidebar { host.traitOverrides.horizontalSizeClass = wanted }
        if sidebar { host.traitOverrides.verticalSizeClass = .regular }
        window.overrideUserInterfaceStyle = job.scheme == .dark ? .dark : .light
        window.frame = CGRect(origin: .zero, size: job.pose.canvas)
        window.rootViewController = host
        window.isHidden = false
        window.layoutIfNeeded()
        // Tab bars and split views finish their first layout asynchronously; plain views don't.
        let slow: Set<LabID> = [.tabBar, .toolbars, .listDetail, .media, .continuity, .toasts, .laptopPose, .twoPanes, .keyboard, .transitions]
        try? await Task.sleep(for: .milliseconds(slow.contains(job.lab) ? 450 : 160))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: job.pose.canvas, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.rootViewController = nil
        return image
    }

    private func window(_ slot: Int) -> UIWindow? {
        if let window = windows[slot] { return window }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return nil }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue - 1 - CGFloat(slot))
        window.isUserInteractionEnabled = false
        windows[slot] = window
        return window
    }

    /// Readable prefix plus a stable hash of the full key, so `a-1` and `a_1` never share a file.
    private func file(_ key: String) -> URL {
        let safe = String(key.map { $0.isLetter || $0.isNumber ? $0 : "_" }.prefix(120))
        var hash: UInt64 = 0xcbf29ce484222325 // FNV-1a, stable across launches unlike Hasher
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return directory.appending(path: safe + "-" + String(hash, radix: 16) + ".png")
    }

    private func loadFromDisk(_ key: String) -> UIImage? {
        guard let data = try? Data(contentsOf: file(key)) else { return nil }
        return UIImage(data: data, scale: 1)
    }

    private func saveToDisk(_ image: UIImage, key: String) {
        guard let data = image.pngData() else { return }
        try? data.write(to: file(key), options: .atomic)
    }
}
