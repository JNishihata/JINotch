//
//  NotchExpanded.swift
//  JINotch
//
//  DynamicNotchKit を使わずに、ノッチ下へ黒いパネルを展開表示するための自作実装。
//  透明ボーダーレスウィンドウ + SwiftUI(NSHostingView) で構成し、
//  ノッチ下端から生えるようにスプリングアニメーションで開閉する。
//

import SwiftUI
import Cocoa
import Combine

// MARK: - パネル形状(下だけ角丸)

/// 上辺は角ばったまま(ノッチと一体化させる)、下側だけ角丸にした形。
struct NotchPanelShape: Shape {
    /// 上側の逆アール半径(画面・メニューバーと一体化する角。外側に膨らむ)。
    var topCornerRadius: CGFloat = 10
    /// 下側の通常の角丸半径。
    var bottomCornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = min(topCornerRadius, rect.width / 2, rect.height)
        let bottom = min(bottomCornerRadius, rect.width / 2 - top, rect.height - top)

        // 上辺は左端から始まる(rect 全幅がノッチ下端に接する部分)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // 左上: 外側へ膨らむ逆アール(直角ではなく、外に反った角)
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY + top),
            control: CGPoint(x: rect.minX + top, y: rect.minY)
        )
        // 左辺(本体は左右とも top ぶん内側)
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        // 左下: 通常の角丸
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
            control: CGPoint(x: rect.minX + top, y: rect.maxY)
        )
        // 下辺
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        // 右下: 通常の角丸
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
            control: CGPoint(x: rect.maxX - top, y: rect.maxY)
        )
        // 右辺
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        // 右上: 外側へ膨らむ逆アール
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - top, y: rect.minY)
        )
        // 上辺を閉じる
        path.closeSubpath()
        return path
    }
}

// MARK: - 展開状態モデル

/// 下パネルの開閉状態と中身を持つ。AppKit 側から更新し、SwiftUI が追従する。
@MainActor
final class NotchExpandedModel: ObservableObject {
    @Published var isExpanded = false

    /// ノッチ真下のメイン領域。
    @Published var content: AnyView = AnyView(EmptyView())
    /// heading bar 左(ノッチ左脇)。
    @Published var headingLeading: AnyView = AnyView(EmptyView())
    /// heading bar 右(ノッチ右脇)。
    @Published var headingTrailing: AnyView = AnyView(EmptyView())

    /// 畳んだとき(＝ノッチそのもの)のサイズ。ここから中身の実寸へ広がる。
    /// width はノッチ幅(＝heading bar 中央の空き)、height はノッチ高さ(＝heading bar の高さ)。
    @Published var collapsedSize: CGSize = CGSize(width: 300, height: 32)

    /// 展開時の最低横幅。中身が小さくてもこれ以上は縮まない(0 なら無制限)。
    @Published var minWidth: CGFloat = 0

    /// 本体(ノッチ真下)まわりに全方向でかける余白。
    @Published var contentPadding: CGFloat = 0

    /// パネル上にマウスが乗ったか(展開維持の判定に使う)。
    var onHover: ((Bool) -> Void)?
}

// MARK: - 実寸測定用 PreferenceKey

private struct NotchMainSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
private struct NotchHeadLeadingSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
private struct NotchHeadTrailingSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

// MARK: - 展開パネルのルートビュー

struct NotchExpandedRoot: View {
    @ObservedObject var model: NotchExpandedModel
    @State private var mainSize: CGSize = .zero
    @State private var headLeadingSize: CGSize = .zero
    @State private var headTrailingSize: CGSize = .zero

    /// heading 項目のパネル端からの余白。
    private let edgeInset: CGFloat = 18
    /// heading 項目とノッチの間に最低限あける間隔。
    private let notchPad: CGFloat = 12

    private var notchSize: CGSize { model.collapsedSize }

    /// heading 片側に確保したい幅(項目幅 + ノッチ側の最小間隔)。
    /// 左右で大きい方に合わせ、パネルはノッチ中心に対して対称に広げる。
    private var headingSideNeeded: CGFloat {
        max(headLeadingSize.width, headTrailingSize.width) + notchPad
    }

    /// 本体(ノッチ真下)に padding を足した実効サイズ。
    /// 余白は左・右・下のみ(上＝ノッチ側は付けず、ギリギリまで配置できるようにする)。
    private var mainPaddedSize: CGSize {
        guard mainSize != .zero else { return .zero }
        let p = model.contentPadding
        return CGSize(width: mainSize.width + 2 * p, height: mainSize.height + p)
    }

    /// 展開しきったときのパネル全体サイズ。
    /// 幅は「最低横幅」「本体幅(+padding)」「ノッチ幅 + 両脇の heading 必要幅」の最大。
    /// → heading が大きくてノッチに被りそうなら、パネルが広がってノッチを避ける。
    private var fullSize: CGSize {
        let width = max(
            model.minWidth,
            mainPaddedSize.width,
            notchSize.width + 2 * headingSideNeeded
        )
        return CGSize(width: width, height: notchSize.height + mainPaddedSize.height)
    }

    /// いま表示すべき黒パネルの箱サイズ。
    /// 展開時は fullSize、畳むときはノッチサイズ。ここをアニメーションさせる。
    private var boxSize: CGSize {
        if model.isExpanded, mainSize != .zero {
            return fullSize
        }
        return notchSize
    }

    var body: some View {
        VStack(spacing: 0) {
            panel
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// heading bar: ノッチの高さぶんの帯。左右の項目をそれぞれパネルの端に寄せる。
    /// 中央(ノッチのある部分)は headingSideNeeded の確保により常に空く。
    private var headingBar: some View {
        ZStack {
            // 左: 左端に寄せる
            HStack(spacing: 0) {
                model.headingLeading
                    .fixedSize()
                    .padding(.leading, edgeInset)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: NotchHeadLeadingSizeKey.self, value: geo.size)
                        }
                    )
                Spacer(minLength: 0)
            }
            // 右: 右端に寄せる
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                model.headingTrailing
                    .fixedSize()
                    .padding(.trailing, edgeInset)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: NotchHeadTrailingSizeKey.self, value: geo.size)
                        }
                    )
            }
        }
        .frame(width: fullSize.width, height: notchSize.height)
        .foregroundStyle(.white)
        .font(.system(size: 12, weight: .medium))
    }

    /// メイン領域(ノッチ真下)。実寸を測定してから余白をかける。
    /// 上(ノッチ側)は付けず、左・右・下のみ。
    private var mainArea: some View {
        model.content
            .fixedSize()
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: NotchMainSizeKey.self, value: geo.size)
                }
            )
            .padding(.horizontal, model.contentPadding)
            .padding(.bottom, model.contentPadding)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            headingBar
            mainArea
        }
        .opacity(model.isExpanded ? 1 : 0)
        // ↑ここまでが中身。以下で「ノッチが広がる箱」に切り取る。
        .frame(width: boxSize.width, height: boxSize.height, alignment: .top)
        .background(NotchPanelShape().fill(Color.black))
        .clipShape(NotchPanelShape())
        .overlay(
            NotchPanelShape()
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .onHover { model.onHover?($0) }
        .onPreferenceChange(NotchMainSizeKey.self) { mainSize = $0 }
        .onPreferenceChange(NotchHeadLeadingSizeKey.self) { headLeadingSize = $0 }
        .onPreferenceChange(NotchHeadTrailingSizeKey.self) { headTrailingSize = $0 }
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: model.isExpanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: mainSize)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: fullSize.width)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: fullSize.height)
    }
}

// MARK: - 展開パネル用ウィンドウ

/// ノッチ下に重ねる透明ボーダーレスウィンドウ。
final class NotchExpandedWindow: NSWindow {
    init(frame: CGRect, hosting: NSView) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.level = .statusBar
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        hosting.frame = NSRect(origin: .zero, size: frame.size)
        self.contentView = hosting
    }
}
