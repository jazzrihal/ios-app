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
            ScrollView {
                VStack(spacing: 8) {
                    dateSelector
                    locationSelector
                    searchButton
                    saveMomentButton
                    resultsSection
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Date Selector

    private var dateSelector: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.toggleDatePicker()
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search around")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.selectedDate.formatted(.dateTime.month(.wide).day().year().hour().minute()))
                            .font(.subheadline.weight(.medium))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(viewModel.showDatePicker ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            if viewModel.showDatePicker {
                dateShortcuts

                DatePicker(
                    "Select date & time",
                    selection: $viewModel.selectedDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Date Shortcuts

    private var dateShortcuts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExploreViewModel.DateShortcut.allCases) { shortcut in
                    Button {
                        viewModel.applyDateShortcut(shortcut)
                    } label: {
                        Text(shortcut.rawValue)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(.primary)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Location Selector

    private var locationSelector: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.toggleMap()
            } label: {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3)
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if viewModel.isReverseGeocoding {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("Finding location…")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        } else if let locationName = viewModel.locationName {
                            Text(locationName)
                                .font(.subheadline.weight(.medium))
                        } else {
                            Text("Tap to choose on map")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(viewModel.showMap ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

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
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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

    // MARK: - Search Button

    private var searchButton: some View {
        let isDisabled = viewModel.pinnedCoordinate == nil || viewModel.isSearching

        return Button {
            viewModel.performSearch()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSearching {
                    ProgressView()
                        .tint(isDisabled ? Color(.systemGray) : Color(.systemBackground))
                } else {
                    Image(systemName: "magnifyingglass")
                }
                Text(viewModel.isSearching ? "Searching…" : "Find Nearby Posts")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isDisabled ? Color(.systemGray) : Color(.systemBackground))
            .background(isDisabled ? Color(.systemGray5) : Color.primary, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityIdentifier("FindNearbyPostsButton")
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .padding(.horizontal, 16)
    }

    // MARK: - Save Moment Button

    @ViewBuilder private var saveMomentButton: some View {
        if viewModel.hasSearched, !viewModel.posts.isEmpty {
            Button {
                viewModel.saveMoment(store: store)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.momentSaved ? "checkmark.circle.fill" : "bookmark.fill")
                    Text(viewModel.momentSaved ? "Moment Saved!" : "Save this Moment")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(viewModel.momentSaved ? Color(.systemGray2) : .primary)
                .background(
                    viewModel.momentSaved ? Color(.systemGray6) : Color.primary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(viewModel.momentSaved ? Color(.systemGray5) : Color.primary.opacity(0.2))
                )
            }
            .accessibilityIdentifier("SaveMomentButton")
            .buttonStyle(.plain)
            .disabled(viewModel.momentSaved)
            .padding(.horizontal, 16)
        }
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
