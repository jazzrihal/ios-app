import MapKit
import Nuke
import SwiftUI

struct ExploreView: View {
    // MARK: - Dependencies

    @Environment(MomentsStore.self) private var store
    @State private var viewModel = ExploreViewModel()
    @State private var prefetcher = ImagePrefetcher()
    @FocusState private var isSearchFieldFocused: Bool

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterHeader

                expandedMap
                expandedDatePicker

                actionButtons

                Divider()

                ScrollView {
                    resultsSection
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: Binding(
                get: { viewModel.navigateToProfileUser != nil },
                set: { if !$0 { viewModel.navigateToProfileUser = nil } }
            )) {
                if let user = viewModel.navigateToProfileUser {
                    FriendProfileView(user: user)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { viewModel.navigateToPostIndex != nil },
                set: { if !$0 { viewModel.navigateToPostIndex = nil } }
            )) {
                if let index = viewModel.navigateToPostIndex {
                    PostDetailView(posts: viewModel.posts, initialIndex: index, queryDate: viewModel.selectedDate)
                }
            }
            .onAppear {
                viewModel.loadPendingMoment(store: store)
            }
            .onChange(of: store.pendingMoment?.id) { _, _ in
                viewModel.loadPendingMoment(store: store)
            }
            .onChange(of: viewModel.posts.map(\.id)) { _, _ in
                let urls = viewModel.posts.map(\.imageURL)
                prefetcher.startPrefetching(with: urls)
            }
        }
    }

    // MARK: - Fixed Filter Header

    private var filterHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.toggleMap()
            } label: {
                HStack {
                    Group {
                        if viewModel.isReverseGeocoding {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("Finding location…")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        } else if let locationName = viewModel.locationName {
                            Text(locationName)
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)
                        } else {
                            Text("Choose a location")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(viewModel.showMap ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)

            Button {
                viewModel.toggleDatePicker()
            } label: {
                HStack {
                    Text(viewModel.selectedDate.formatted(.dateTime.month(.wide).day().year().hour().minute()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(viewModel.showDatePicker ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Expanded Date Picker

    @ViewBuilder private var expandedDatePicker: some View {
        if viewModel.showDatePicker {
            VStack(spacing: 12) {
                dateShortcuts

                HStack {
                    DatePicker(
                        "Date & time",
                        selection: $viewModel.selectedDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)

                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 6)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Date Shortcuts

    private var dateShortcuts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ExploreViewModel.DateShortcut.allCases) { shortcut in
                    Button {
                        viewModel.applyDateShortcut(shortcut)
                    } label: {
                        Text(shortcut.rawValue)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(.secondary)
                            .background(Color.primary.opacity(0.04), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Expanded Map

    @ViewBuilder private var expandedMap: some View {
        if viewModel.showMap {
            VStack(alignment: .leading, spacing: 8) {
                placeSearchBar

                if !viewModel.searchCompleter.results.isEmpty, !viewModel.searchCompleter.queryFragment.isEmpty {
                    placeSearchResults
                }

                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(.secondary)
                    Text(viewModel.pinnedCoordinate != nil ? "Tap the map to move pin" : "Tap the map to drop a pin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                MapReader { proxy in
                    Map(position: $viewModel.cameraPosition) {
                        if let pin = viewModel.pinnedCoordinate {
                            Annotation("Search here", coordinate: pin) {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Circle()
                                        .fill(Color.primary.opacity(0.2))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white, .primary)
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
                    .onTapGesture { screenPoint in
                        if let coord = proxy.convert(screenPoint, from: .local) {
                            isSearchFieldFocused = false
                            viewModel.handleMapTap(coordinate: coord)
                        }
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Place Search Bar

    private var placeSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            TextField("Search for a place…", text: Binding(
                get: { viewModel.searchCompleter.queryFragment },
                set: { viewModel.searchCompleter.queryFragment = $0 }
            ))
            .font(.subheadline)
            .focused($isSearchFieldFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
            .submitLabel(.search)

            if viewModel.isResolvingPlace {
                ProgressView()
                    .controlSize(.mini)
            } else if !viewModel.searchCompleter.queryFragment.isEmpty {
                Button {
                    isSearchFieldFocused = false
                    viewModel.dismissPlaceSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Place Search Results

    private var placeSearchResults: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.searchCompleter.results.prefix(5), id: \.self) { completion in
                Button {
                    isSearchFieldFocused = false
                    viewModel.selectPlace(completion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.turn.down.left")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if completion != viewModel.searchCompleter.results.prefix(5).last {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.performSearch()
            } label: {
                HStack(spacing: 5) {
                    if viewModel.isSearching {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(viewModel.isSearching ? "Searching…" : "Search")
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(viewModel.pinnedCoordinate == nil ? .tertiary : .primary)
                .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .accessibilityIdentifier("FindNearbyPostsButton")
            .buttonStyle(.plain)
            .disabled(viewModel.pinnedCoordinate == nil || viewModel.isSearching)

            if viewModel.hasSearched, !viewModel.posts.isEmpty {
                Button {
                    viewModel.saveMoment(store: store)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: viewModel.momentSaved ? "checkmark" : "bookmark")
                        Text(viewModel.momentSaved ? "Saved" : "Save Moment")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(viewModel.momentSaved ? .tertiary : .primary)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                }
                .accessibilityIdentifier("SaveMomentButton")
                .buttonStyle(.plain)
                .disabled(viewModel.momentSaved)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        Group {
            if viewModel.hasSearched {
                if viewModel.posts.isEmpty {
                    ContentUnavailableView(
                        "No Posts Found",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Try a different location or time range.")
                    )
                    .padding(.top, 28)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                            PostCard(
                                post: post,
                                queryDate: viewModel.selectedDate,
                                onTapProfile: {
                                    viewModel.navigateToProfileUser = post.user
                                },
                                onTapPost: {
                                    viewModel.navigateToPostIndex = index
                                }
                            )
                            if index < viewModel.posts.count - 1 {
                                Divider()
                                    .foregroundStyle(.quaternary)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Pick a date & drop a pin to explore")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExploreView()
        .environment(MomentsStore())
        .environment(FriendsStore())
        .environment(AuthManager())
}
