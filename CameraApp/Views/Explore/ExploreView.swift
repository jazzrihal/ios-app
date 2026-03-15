import MapKit
import Nuke
import NukeUI
import SwiftUI

struct ExploreView: View {
    // MARK: - Dependencies

    @Environment(MomentsStore.self) private var store
    @Environment(PostMutationStore.self) private var postMutationStore
    @Environment(DefaultPostRepository.self) private var postRepository
    @State private var viewModel = ExploreViewModel()
    @State private var prefetcher = ImagePrefetcher()
    @FocusState private var isSearchFieldFocused: Bool

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    filterHeader

                    expandedMap
                    expandedDatePicker

                    actionButtons

                    Divider()

                    resultsSection
                }
            }
            .tabLoadable(
                isLoading: !viewModel.hasSearched && (viewModel.isFetchingLocation || viewModel.isSearching),
                isRefreshing: viewModel.isRefreshing,
                onRefresh: { await viewModel.refreshSearch() }
            )
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
                viewModel.postRepository = postRepository
                viewModel.loadPendingMoment(store: store)
                viewModel.fetchCurrentLocationOnLaunch()
            }
            .onChange(of: store.pendingMoment?.id) { _, _ in
                viewModel.loadPendingMoment(store: store)
            }
            .onChange(of: viewModel.posts.map(\.id)) { _, _ in
                let urls = viewModel.posts.map(\.imageURL)
                prefetcher.startPrefetching(with: urls)
                postMutationStore.seedFromPosts(viewModel.posts)
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
                        if viewModel.isFetchingLocation || viewModel.isReverseGeocoding {
                            HStack(spacing: AppStyle.Spacing.compact) {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("LocationPickerButton")
            .padding(.bottom, AppStyle.Spacing.row)

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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("DateSelectorButton")
        }
        .padding(.horizontal, AppStyle.Padding.screenHorizontal)
        .padding(.vertical, AppStyle.Padding.cardInner)
    }

    // MARK: - Expanded Date Picker

    @ViewBuilder private var expandedDatePicker: some View {
        if viewModel.showDatePicker {
            VStack(spacing: AppStyle.Spacing.medium) {
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
                .padding(.horizontal, AppStyle.Padding.screenHorizontal)
            }
            .padding(.bottom, AppStyle.Spacing.compact)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Date Shortcuts

    private var dateShortcuts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppStyle.Spacing.row) {
                ForEach(ExploreViewModel.DateShortcut.allCases) { shortcut in
                    Button {
                        viewModel.applyDateShortcut(shortcut)
                    } label: {
                        Text(shortcut.rawValue)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, AppStyle.Spacing.row)
                            .padding(.vertical, 5)
                            .foregroundStyle(.secondary)
                            .background(Color.primary.opacity(0.04), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppStyle.Padding.screenHorizontal)
        }
        .padding(.top, AppStyle.Spacing.small)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Expanded Map

    @ViewBuilder private var expandedMap: some View {
        if viewModel.showMap {
            VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
                AppSearchBar(
                    text: Binding(
                        get: { viewModel.searchCompleter.queryFragment },
                        set: { viewModel.searchCompleter.queryFragment = $0 }
                    ),
                    placeholder: "Search for a place…",
                    isLoading: viewModel.isResolvingPlace,
                    capitalization: .words,
                    focusField: $isSearchFieldFocused,
                    onClear: {
                        isSearchFieldFocused = false
                        viewModel.dismissPlaceSearch()
                    }
                )

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
                .padding(.horizontal, AppStyle.Spacing.tight)

                MapReader { proxy in
                    Map(position: $viewModel.cameraPosition) {
                        if let pin = viewModel.pinnedCoordinate {
                            Annotation("Search here", coordinate: pin) {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(0.1))
                                        .frame(width: AppStyle.IconSize.tapTarget, height: AppStyle.IconSize.tapTarget)
                                    Circle()
                                        .fill(Color.primary.opacity(0.2))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color(.systemBackground), .primary)
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
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: AppStyle.Padding.screenHorizontal))
            }
            .padding(.horizontal, AppStyle.Padding.screenHorizontal)
            .padding(.top, AppStyle.Spacing.small)
            .padding(.bottom, AppStyle.Spacing.small)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Place Search Results

    private var placeSearchResults: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.searchCompleter.results.prefix(5), id: \.self) { completion in
                Button {
                    isSearchFieldFocused = false
                    viewModel.selectPlace(completion)
                } label: {
                    HStack(spacing: AppStyle.Spacing.row) {
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
                    .padding(.horizontal, AppStyle.Padding.cardInner)
                    .padding(.vertical, AppStyle.Spacing.row)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if completion != viewModel.searchCompleter.results.prefix(5).last {
                    Divider()
                        .padding(.leading, AppStyle.IconSize.tapTarget)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.control))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                if viewModel.hasSearched, !viewModel.posts.isEmpty {
                    Button {
                        viewModel.saveMoment(store: store)
                    } label: {
                        VStack(spacing: AppStyle.Spacing.tight) {
                            Image(systemName: viewModel.momentSaved ? "checkmark" : "bookmark")
                                .contentTransition(.identity)
                                .font(.title2)
                                .frame(width: 28, height: 28)
                            Text("Save Moment")
                                .font(.caption2.weight(.medium))
                                .hidden()
                                .overlay {
                                    Text(viewModel.momentSaved ? "Saved" : "Save Moment")
                                        .contentTransition(.identity)
                                        .font(.caption2.weight(.medium))
                                }
                        }
                        .foregroundStyle(viewModel.momentSaved ? .tertiary : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppStyle.Spacing.row)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("SaveMomentButton")
                    .disabled(viewModel.momentSaved)
                }

                Button {
                    Task { await viewModel.performSearch() }
                } label: {
                    VStack(spacing: AppStyle.Spacing.tight) {
                        ZStack {
                            if viewModel.isSearching {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .contentTransition(.identity)
                            }
                        }
                        .font(.title2)

                        Text("Search")
                            .contentTransition(.identity)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(viewModel.pinnedCoordinate == nil ? .tertiary : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppStyle.Spacing.row)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("FindNearbyPostsButton")
                .disabled(viewModel.pinnedCoordinate == nil || viewModel.isSearching)
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        Group {
            if viewModel.hasSearched {
                if viewModel.posts.isEmpty {
                    EmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: "No Posts Found",
                        subtitle: "Try a different location or time range."
                    )
                } else {
                    PhotoGrid(
                        items: viewModel.posts,
                        columns: 2,
                        hasMorePages: viewModel.hasMorePages,
                        isLoadingMore: viewModel.isLoadingMore,
                        onLoadMore: { Task { await viewModel.loadNextPage() } },
                        cell: { index, post in
                            Button {
                                viewModel.navigateToPostIndex = index
                            } label: {
                                RemoteImage(url: post.imageURL)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("ExplorePostCell_\(index)")
                        }
                    )
                }
            } else if !viewModel.isFetchingLocation, !viewModel.isSearching {
                EmptyStateView(
                    icon: "sparkle.magnifyingglass",
                    title: "Pick a date & drop a pin to explore"
                )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        ExploreView()
            .environment(MomentsStore())
            .environment(PostMutationStore())
            .environment(FriendsStore())
            .environment(AuthManager())
            .environment(PreviewContainer.postRepository)
    }
#endif
