//
//  RepoListView.swift
//  Presentation
//
//  Created by okudera on 2022/02/23.
//

import AppCore
import SwiftUI

public protocol RepoListViewInput: AnyObject {
    func repoListViewSearchRepositories(searchQuery: String)
    func repoListViewLoadMoreRepositories()
    func repoListViewDidTapRepository(_ repository: GitHubRepository)
}

public struct RepoListView: View {

    weak var input: RepoListViewInput?

    @ObservedObject
    private var dataSource: DataSource

    public init(input: RepoListViewInput?, dataSource: DataSource) {
        self.input = input
        self.dataSource = dataSource
    }

    public var body: some View {
        SearchNavigation(
            text: $dataSource.inputText,
            search: { input?.repoListViewSearchRepositories(searchQuery: dataSource.inputText) }
        ) {
            List {
                ForEach(dataSource.repositories) { repository in
                    RepoListRow(title: repository.fullName, language: repository.language ?? "") {
                        print(repository.fullName, repository.language ?? "")
                        input?.repoListViewDidTapRepository(repository)
                    }
                }
                HStack {
                    Spacer()
                    ProgressView()
                        .onAppear {
                            input?.repoListViewLoadMoreRepositories()
                        }
                    Spacer()
                }
                // 次のページがない場合、リスト末尾にインジケーターを表示しない
                .hidden(!dataSource.hasNext)
            }
            .alert(isPresented: $dataSource.isErrorShown) { () -> Alert in
                Alert(
                    title: Text(dataSource.errorTitle),
                    message: Text(dataSource.errorMessage),
                    primaryButton: .default(
                        Text("retry", bundle: .module), action: dataSource.retryHandler),
                    secondaryButton: .cancel(Text("cancel", bundle: .module))
                )
            }
            .navigationBarTitle(Text("repo_list_view.navigation_bar_title", bundle: .module))
        }
        .edgesIgnoringSafeArea([.top, .bottom])
    }
}

// MARK: - DataSource
extension RepoListView {
    public class DataSource: ObservableObject {
        @Published var inputText = ""
        @Published var isErrorShown = false
        @Published var repositories = [GitHubRepository]()
        @Published var hasNext = false

        var errorTitle = ""
        var errorMessage = ""
        var retryHandler: (() -> Void)? = nil
    }
}

extension RepoListView.DataSource {
    static let mock: RepoListView.DataSource = {
        let mock = RepoListView.DataSource()
        mock.inputText = "Swift"
        mock.repositories = [
            .init(
                id: 1,
                fullName: "y-okudera/SwiftUIApp",
                description: "Swift Package based App.",
                stargazersCount: 1234,
                language: "Swift",
                htmlUrl: URL(string: "https://github.com/y-okudera/SwiftUIApp")!,
                owner: GitHubUser(
                    id: 100,
                    login: "mock",
                    avatarUrl: URL(string: "https://avatars.githubusercontent.com/u/25205138?v=4")!,
                    htmlUrl: URL(string: "https://github.com/y-okudera")!,
                    type: "User"
                )
            )
        ]
        return mock
    }()
}

#if DEBUG
    struct RepoListView_Previews: PreviewProvider {
        static var previews: some View {
            AppPreview {
                RepoListView(input: nil, dataSource: .mock)
            }
        }
    }
#endif
