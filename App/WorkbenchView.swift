import AppKit
import SwiftUI
import StillDockCore

private enum Palette {
    static let canvas = Color(red: 0.963, green: 0.962, blue: 0.945)
    static let paper = Color(red: 0.992, green: 0.991, blue: 0.978)
    static let ink = Color(red: 0.16, green: 0.22, blue: 0.21)
    static let muted = Color(red: 0.39, green: 0.44, blue: 0.42)
    static let teal = Color(red: 0.13, green: 0.42, blue: 0.37)
    static let tealWash = Color(red: 0.88, green: 0.93, blue: 0.89)
    static let line = Color(red: 0.86, green: 0.88, blue: 0.84)
    static let amber = Color(red: 0.53, green: 0.35, blue: 0.13)
    static let amberWash = Color(red: 0.97, green: 0.93, blue: 0.81)
}

struct WorkbenchView: View {
    @ObservedObject var model: WorkbenchModel
    @State private var isDropTarget = false
    @State private var showingIssues = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Palette.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                header
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 14) {
                        if model.photos.isEmpty { emptyState } else { photoWorkbench }
                        if !model.issues.isEmpty { issueBanner }
                        if model.isBusy { progressPanel }
                        else if let summary = model.exportSummary { completionPanel(summary) }
                        safetyNote
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    exportPanel
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.canvas)
        .foregroundStyle(Palette.ink)
        .tint(Palette.teal)
        .sheet(isPresented: $showingIssues) { issuesSheet }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Palette.teal).frame(width: 35, height: 35)
                    Image(systemName: "photo.stack").font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                }
                Text("StillDock").font(.system(size: 21, weight: .semibold, design: .rounded)).tracking(-0.8)
            }
            .padding(.top, 43)
            Text("사진의 작은 정리 공간")
                .font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.top, 9)
            Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 28)
            Text("공유 준비").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(Palette.muted)
                .padding(.bottom, 19)
            step("01", title: "사진 추가", detail: "한 번에 최대 100장", active: model.photos.isEmpty, done: !model.photos.isEmpty)
            step("02", title: "내보내기 설정", detail: "포맷과 크기 선택", active: !model.photos.isEmpty && model.exportSummary == nil, done: model.exportSummary != nil)
            step("03", title: "새 복사본 저장", detail: "원본은 그대로", active: model.exportSummary != nil, done: false)
            Spacer(minLength: 30)
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "externaldrive.badge.checkmark")
                    .font(.system(size: 21, weight: .light)).foregroundStyle(Palette.teal)
                Text("이 Mac 안에서만.").font(.system(size: 13, weight: .semibold))
                Text("사진 처리에 업로드나\n계정이 필요하지 않습니다.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.tealWash.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 6) {
                Circle().fill(Palette.teal).frame(width: 5, height: 5)
                Text("LOCAL BY DESIGN").font(.system(size: 9, weight: .medium)).tracking(1.0)
            }
            .foregroundStyle(Palette.muted).padding(.top, 17).padding(.bottom, 24)
        }
        .padding(.horizontal, 21)
        .frame(width: 198)
        .background(Palette.paper)
    }

    private func step(_ number: String, title: String, detail: String, active: Bool, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(active ? Palette.teal : Palette.tealWash.opacity(done ? 0.8 : 0.3)).frame(width: 27, height: 27)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.teal)
                } else {
                    Text(number).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(active ? .white : Palette.muted)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: active ? .semibold : .medium))
                Text(detail).font(.system(size: 10)).foregroundStyle(Palette.muted)
            }.padding(.top, 1)
        }.padding(.bottom, 23)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 9) {
                Text("PHOTO WORKBENCH").font(.system(size: 10, weight: .semibold)).tracking(1.7).foregroundStyle(Palette.teal)
                Text("공유 전, 한 번 정리.")
                    .font(.system(size: 27, weight: .semibold)).tracking(-1.2)
                Text("위치와 촬영 정보를 덜어낸 새 사진을 만드세요.")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 12)
            Button { model.chooseImages() } label: {
                Label("사진 추가", systemImage: "plus").font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Palette.paper, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.line, lineWidth: 1))
            }
            .buttonStyle(.plain).disabled(model.isLocked)
            .help("사진 추가 (⌘O)").accessibilityIdentifier("addPhotosButton")
        }
        .padding(.horizontal, 28).padding(.top, 40).padding(.bottom, 27)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            PhotoIllustration().frame(width: 232, height: 158).padding(.bottom, 24)
            Text("보내고 싶은 사진을 놓아주세요")
                .font(.system(size: 19, weight: .semibold)).tracking(-0.6)
            Text("사진을 끌어오거나, 아래에서 선택하세요.\nJPEG · PNG · HEIC  /  최대 100장")
                .font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                .lineSpacing(7).padding(.top, 12)
            Button { model.chooseImages() } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus")
                    Text("사진 선택하기").fontWeight(.semibold)
                    Text("⌘O").foregroundStyle(.white.opacity(0.6)).padding(.leading, 8)
                }
                .font(.system(size: 12)).foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Palette.teal, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain).disabled(model.isLocked).padding(.top, 25)
            .accessibilityIdentifier("choosePhotosButton")
            Spacer(minLength: 24)
            HStack(spacing: 8) {
                Image(systemName: "square.on.square").font(.system(size: 12))
                Text("원본을 바꾸지 않고, 새 복사본으로 저장합니다.").font(.system(size: 11))
            }
            .foregroundStyle(Palette.muted).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isDropTarget && !model.isLocked ? Palette.tealWash : Palette.paper, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(isDropTarget && !model.isLocked ? Palette.teal : Palette.line,
                                                               style: StrokeStyle(lineWidth: isDropTarget ? 2 : 1, dash: [6, 5])))
        .dropDestination(for: URL.self) { urls, _ in
            guard !model.isLocked else { return false }
            model.importImages(urls)
            return true
        } isTargeted: { isDropTarget = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("emptyDropZone")
    }

    private var photoWorkbench: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Text("선택한 사진").font(.system(size: 12, weight: .semibold))
                Text("\(model.photos.count)").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6).padding(.vertical, 3).background(Palette.tealWash, in: Capsule())
                Spacer()
                Button("비우기") { model.clear() }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(Palette.muted)
                    .disabled(model.isLocked).accessibilityIdentifier("clearPhotosButton")
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            Rectangle().fill(Palette.line).frame(height: 1)
            if let photo = model.selectedPhoto {
                selectedPreview(photo)
                Rectangle().fill(Palette.line).frame(height: 1)
            }
            ScrollView(.vertical) {
                LazyVStack(spacing: 3) {
                    ForEach(model.photos) { photo in photoRow(photo) }
                }.padding(7)
            }
            .frame(minHeight: 96, maxHeight: model.exportSummary == nil && !model.isBusy ? 174 : 115)
            HStack {
                Text("합계 \(WorkbenchModel.bytes(model.inputBytes))")
                Spacer()
                Text("더 추가하려면 여기로 드래그")
            }
            .font(.system(size: 10)).foregroundStyle(Palette.muted)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Palette.canvas.opacity(0.5))
        }
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isDropTarget && !model.isLocked ? Palette.teal : Palette.line, lineWidth: isDropTarget ? 2 : 1))
        .dropDestination(for: URL.self) { urls, _ in
            guard !model.isLocked else { return false }
            model.importImages(urls)
            return true
        } isTargeted: { isDropTarget = $0 }
        .accessibilityIdentifier("photoWorkbench")
    }

    private func selectedPreview(_ photo: PhotoItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 9).fill(Palette.canvas)
                Image(nsImage: photo.thumbnail).resizable().scaledToFit().padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .accessibilityLabel("선택한 사진 미리보기: \(photo.url.lastPathComponent)")
                Text("원본 미리보기").font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.muted)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Palette.paper.opacity(0.93), in: Capsule()).padding(10)
            }
            .frame(minHeight: 130, idealHeight: 228, maxHeight: .infinity)
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: photo.hasGPS ? "location.fill" : "info.circle")
                    .font(.system(size: 10))
                Text("원본 · " + (photo.hasGPS ? "위치 메타데이터 감지" : (photo.inspection.metadataGroups.isEmpty ? "검사 범위에서 민감 메타데이터 감지 없음" : "촬영 메타데이터 감지")))
                    .font(.system(size: 10, weight: .medium))
                Spacer(minLength: 5)
                if photo.result != nil {
                    Button { model.revealSelectedExport() } label: {
                        Image(systemName: "arrow.up.forward.square").font(.system(size: 12))
                    }.buttonStyle(.plain).help("저장된 사진을 Finder에서 보기")
                        .accessibilityLabel("저장된 사진을 Finder에서 보기")
                }
            }
            .foregroundStyle(photo.hasGPS ? Palette.amber : Palette.muted)
            if let result = photo.result {
                Text("저장본  \(result.width) × \(result.height)  ·  \(WorkbenchModel.bytes(result.outputBytes))")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.teal)
                    .accessibilityIdentifier("selectedExportDetails")
            }
        }
        .padding(14)
    }

    private func photoRow(_ photo: PhotoItem) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: photo.thumbnail).resizable().scaledToFill()
                .frame(width: 44, height: 40).clipped().clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 5) {
                Text(photo.url.lastPathComponent).font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.middle)
                Text("\(photo.inspection.width) × \(photo.inspection.height)  ·  \(WorkbenchModel.bytes(photo.inspection.inputBytes))")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 4)
            if photo.result != nil {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.teal).help("복사본 저장 및 메타데이터 검사 완료")
            } else if photo.exportError != nil {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.amber).help(photo.exportError ?? "")
            } else if photo.hasGPS {
                Text("GPS").font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.amber).padding(.horizontal, 5).padding(.vertical, 4)
                    .background(Palette.amberWash, in: RoundedRectangle(cornerRadius: 4))
            }
            if model.selectedID == photo.id {
                Button { model.removeSelection() } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.muted).frame(width: 20, height: 24)
                }.buttonStyle(.plain).disabled(model.isLocked).help("선택한 사진 제거")
                    .accessibilityLabel("선택한 사진 제거").accessibilityIdentifier("removePhotoButton")
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(model.selectedID == photo.id ? Palette.tealWash.opacity(0.65) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { model.selectedID = photo.id }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(photo.url.lastPathComponent), \(photo.inspection.width) × \(photo.inspection.height)")
        .accessibilityAddTraits(model.selectedID == photo.id ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction { model.selectedID = photo.id }
        .accessibilityIdentifier("photoRow-\(photo.url.lastPathComponent)")
    }

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("내보내기").font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "slider.horizontal.3").font(.system(size: 13)).foregroundStyle(Palette.muted)
            }.padding(.bottom, 20)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
            fieldLabel("파일 포맷")
            Picker("파일 포맷", selection: $model.format) {
                Text("JPEG").tag(ExportFormat.jpeg)
                Text("PNG").tag(ExportFormat.png)
            }
            .pickerStyle(.segmented).labelsHidden().padding(.top, 9)
            .accessibilityIdentifier("formatPicker")
                Text(model.format == .jpeg ? "사진 공유에 적합한 압축 포맷" : "투명 배경을 유지하는 이미지 포맷")
                .font(.system(size: 10)).foregroundStyle(Palette.muted).padding(.top, 8)
            fieldLabel("긴 변의 최대 길이").padding(.top, 20)
            Picker("긴 변의 최대 길이", selection: $model.maxPixelSize) {
                Text("원본 크기").tag(0)
                Text("2,560 px").tag(2560)
                Text("1,920 px").tag(1920)
                Text("1,280 px").tag(1280)
            }
            .labelsHidden().pickerStyle(.menu).padding(.top, 8)
            .accessibilityIdentifier("sizePicker")
            Text("비율 유지 · 작은 사진은 확대하지 않음")
                .font(.system(size: 10)).foregroundStyle(Palette.muted).padding(.top, 8)
            if model.format == .jpeg {
                HStack {
                    fieldLabel("JPEG 품질")
                    Spacer()
                    Text("\(Int((model.quality * 100).rounded()))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Palette.teal)
                }.padding(.top, 20)
                Slider(value: $model.quality, in: 0.5...1, step: 0.01).padding(.top, 6)
                    .accessibilityLabel("JPEG 품질").accessibilityValue("\(Int((model.quality * 100).rounded()))퍼센트")
                    .accessibilityIdentifier("qualitySlider")
                HStack { Text("작은 용량"); Spacer(); Text("높은 품질") }
                    .font(.system(size: 9)).foregroundStyle(Palette.muted)
                Label("투명한 영역은 흰색으로 채웁니다.", systemImage: "circle.lefthalf.filled")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted).padding(.top, 13)
            } else {
                Text("PNG는 사진에 따라 원본보다\n파일이 커질 수 있습니다.")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(4).padding(.top, 20)
            }
            Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 18)
            VStack(alignment: .leading, spacing: 12) {
                benefit("위치·촬영 메타데이터 제거", symbol: "location.slash")
                benefit("photo-001부터 새 이름 부여", symbol: "textformat.abc")
                benefit("별도 폴더에 새 복사본 저장", symbol: "folder.badge.plus")
            }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 18)
            HStack {
                Text("저장할 사진").font(.system(size: 11)).foregroundStyle(Palette.muted)
                Spacer()
                Text("\(model.photos.count)장").font(.system(size: 13, weight: .semibold, design: .rounded))
            }.padding(.bottom, 13)
            Button { model.chooseExportDirectory() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text("복사본 저장…").fontWeight(.semibold)
                }
                .font(.system(size: 12)).foregroundStyle(model.canExport ? .white : Palette.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(model.canExport ? Palette.teal : Palette.line.opacity(0.65), in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain).disabled(!model.canExport).accessibilityIdentifier("exportButton")
            Text("저장 위치는 다음 단계에서 선택합니다.")
                .font(.system(size: 9)).foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity).padding(.top, 10)
        }
        .disabled(model.isLocked)
        .padding(20)
        .frame(width: 242)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 11, weight: .semibold))
    }

    private func benefit(_ title: String, symbol: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(Palette.teal).frame(width: 16)
            Text(title).font(.system(size: 10)).foregroundStyle(Palette.muted)
        }
    }

    private var safetyNote: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "eye").font(.system(size: 11)).padding(.top, 1)
            Text("사진 속 얼굴·글자·장소는 그대로 남습니다.\n손상된 사진도 열릴 수 있으니, 미리보기와 저장된 사진을 확인하세요.")
                .font(.system(size: 10)).lineSpacing(4)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.muted).padding(.horizontal, 3)
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(model.operationLabel).font(.system(size: 11, weight: .semibold))
                Spacer()
                Button(model.cancelRequested ? "중단 대기 중…" : "중단") { model.cancel() }
                    .buttonStyle(.plain).font(.system(size: 10)).disabled(model.cancelRequested)
                    .accessibilityIdentifier("cancelOperationButton")
            }
            ProgressView(value: model.progress).progressViewStyle(.linear)
            Text(model.cancelRequested ? "현재 사진 처리가 끝나면 중단합니다." : model.progressDetail)
                .font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1).truncationMode(.middle)
        }
        .padding(14).background(Palette.tealWash.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("operationProgress")
    }

    private func completionPanel(_ summary: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: model.successfulResults.isEmpty ? "info.circle" : "checkmark.circle.fill")
                .font(.system(size: 21)).foregroundStyle(Palette.teal)
            VStack(alignment: .leading, spacing: 5) {
                Text(summary).font(.system(size: 11, weight: .semibold))
                if !model.successfulResults.isEmpty {
                    Text("복사본 \(WorkbenchModel.bytes(model.outputBytes)) · 원본은 변경하지 않았습니다.")
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }
            Spacer(minLength: 6)
            Button { model.revealExports() } label: {
                Image(systemName: "folder").font(.system(size: 15)).padding(9)
                    .background(Palette.paper, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain).help("Finder에서 저장 폴더 보기").accessibilityLabel("Finder에서 저장 폴더 보기")
            .accessibilityIdentifier("revealExportsButton")
        }
        .padding(14).background(Palette.tealWash.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("exportCompletion")
    }

    private var issueBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 12))
            Text("확인이 필요한 항목 \(model.issues.count)개").font(.system(size: 11))
            Spacer()
            Button("자세히") { showingIssues = true }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
                .accessibilityIdentifier("showIssuesButton")
            Button { model.dismissIssues() } label: { Image(systemName: "xmark").font(.system(size: 9)).padding(4) }
                .buttonStyle(.plain).accessibilityLabel("오류 알림 닫기")
        }
        .foregroundStyle(Palette.amber).padding(12)
        .background(Palette.amberWash, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityIdentifier("issueBanner")
    }

    private var issuesSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("확인이 필요한 항목").font(.system(size: 20, weight: .semibold))
            Text("처리할 수 있는 다른 사진은 계속 진행됩니다.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(model.issues) { issue in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(issue.filename).font(.system(size: 12, weight: .semibold)).textSelection(.enabled)
                            Text(issue.message).font(.system(size: 12)).foregroundStyle(Palette.muted).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            HStack { Spacer(); Button("닫기") { showingIssues = false }.keyboardShortcut(.defaultAction) }
        }
        .padding(28).frame(width: 480, height: 360).background(Palette.paper)
    }
}

private struct PhotoIllustration: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Palette.tealWash.opacity(0.7)).frame(width: 224, height: 95).offset(y: 38)
            RoundedRectangle(cornerRadius: 11).fill(Color(red: 0.90, green: 0.87, blue: 0.77))
                .frame(width: 144, height: 111).rotationEffect(.degrees(-13)).offset(x: -28, y: -6)
            RoundedRectangle(cornerRadius: 11).fill(Color(red: 0.74, green: 0.82, blue: 0.75))
                .frame(width: 144, height: 111).rotationEffect(.degrees(9)).offset(x: 28, y: -10)
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 10).fill(Palette.paper)
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.87, green: 0.92, blue: 0.86))
                    Circle().fill(Color(red: 0.87, green: 0.69, blue: 0.35)).frame(width: 22, height: 22).offset(x: -16, y: 12)
                    MountainShape().fill(Color(red: 0.41, green: 0.59, blue: 0.49)).padding(.top, 20)
                    MountainShape().fill(Palette.teal).scaleEffect(x: -0.8, y: 0.65, anchor: .bottom).offset(x: 28, y: 9)
                }.frame(width: 132, height: 85).clipped().clipShape(RoundedRectangle(cornerRadius: 5)).padding(.horizontal, 8).padding(.bottom, 20)
                Capsule().fill(Palette.line).frame(width: 42, height: 3).padding(.leading, 11).padding(.bottom, 9)
            }
            .frame(width: 148, height: 113).rotationEffect(.degrees(-3))
            .shadow(color: Palette.ink.opacity(0.10), radius: 12, x: 0, y: 9)
            ZStack {
                Circle().fill(Palette.teal).frame(width: 39, height: 39)
                Image(systemName: "arrow.down").font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
            }.overlay(Circle().stroke(Palette.paper, lineWidth: 4)).offset(x: 78, y: 42)
        }
        .accessibilityHidden(true)
    }
}

private struct MountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width * 0.39, y: rect.height * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.47, y: rect.height * 0.12), control: CGPoint(x: rect.width * 0.43, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}
