//
//  RepoListActionCreator.swift
//  Application
//
//  Created by Yuki Okudera on 2022/01/05.
//  Copyright © 2022 yuoku. All rights reserved.
//

import Combine
import Domain
import Foundation
import Injected

public protocol RepoListActionCreatorProviding {
  func searchRepositories(inputText: String)
  func additionalSearchRepositories(searchQuery: String, page: Int)
}

public final class RepoListActionCreator: RepoListActionCreatorProviding {

  private let dispatcher: RepoListDispatcher
  private let searchRepositoriesSubject = PassthroughSubject<String, Never>()
  private let responseSubject = PassthroughSubject<RepoAggregateRoot, Never>()
  private let additionalSearchRepositoriesSubject = PassthroughSubject<(String, Int), Never>()
  private let additionalResponseSubject = PassthroughSubject<RepoAggregateRoot, Never>()
  private let errorSubject = PassthroughSubject<APIError, Never>()

  private var cancellables: [AnyCancellable] = []

  @Injected(\.repoRepositoryProvider)
  private var repoRepository: RepoRepositoryProviding

  public init(dispatcher: RepoListDispatcher = .shared) {
    self.dispatcher = dispatcher
    bindData()
    bindActions()
  }

  // MARK: - Input

  public func searchRepositories(inputText: String) {
    searchRepositoriesSubject.send(inputText)
  }

  public func additionalSearchRepositories(searchQuery: String, page: Int) {
    additionalSearchRepositoriesSubject.send((searchQuery, page))
  }

  // MARK: - Binding

  private func bindData() {
    // searchRepositoriesSubjectにstringが送られてきたらAPIリクエストする
    let responseStream =
      searchRepositoriesSubject
      .share()
      .flatMap { [repoRepository] searchQuery in
        repoRepository.response(searchQuery: searchQuery, page: 1)
          .catch { [weak self] apiError -> Empty<RepoAggregateRoot, Never> in
            self?.errorSubject.send(apiError)
            return .init()
          }
      }
      .subscribe(responseSubject)

    // additionalSearchRepositoriesSubjectに(string, int)が送られてきたら追加読み込みのAPIリクエストする
    let additionalResponseStream =
      additionalSearchRepositoriesSubject
      .flatMap { [repoRepository] searchQuery, page in
        repoRepository.response(searchQuery: searchQuery, page: page)
          .catch { [weak self] apiError -> Empty<RepoAggregateRoot, Never> in
            self?.errorSubject.send(apiError)
            return .init()
          }
      }
      .subscribe(additionalResponseSubject)

    cancellables += [
      responseStream,
      additionalResponseStream,
    ]
  }

  private func bindActions() {

    // Pageの初期化とSearchQueryの更新を反映
    let initialSearchStream =
      searchRepositoriesSubject
      .share()
      .sink(receiveValue: { [dispatcher] searchQuery in
        dispatcher.dispatch(.initializePage)
        dispatcher.dispatch(.updateSearchQuery(searchQuery))
      })

    // リポジトリ検索結果を反映
    let responseDataStream =
      responseSubject
      .sink(receiveValue: { [dispatcher] in dispatcher.dispatch(.updateRepoList($0)) })

    // 検索結果が0件の場合、エラーメッセージを更新
    let emptyDataStream =
      responseSubject
      .filter { $0.repositories.isEmpty }
      .map { _ in ("検索結果", "該当するリポジトリがありません。") }
      .sink(receiveValue: { [dispatcher] in dispatcher.dispatch(.updateErrorMessage($0.0, $0.1)) })

    // 検索結果が0件の場合、エラーメッセージを表示
    let isEmptyErrorStream =
      responseSubject
      .filter { $0.repositories.isEmpty }
      .map { _ in }
      .sink(receiveValue: { [dispatcher] in dispatcher.dispatch(.showError) })

    // 追加読み込み結果を反映
    let additionalResponseDataStream =
      additionalResponseSubject
      .sink(receiveValue: { [dispatcher] in dispatcher.dispatch(.updateRepoList($0)) })

    // errorSubjectにerrorが送られてきたら、エラーメッセージを更新
    let errorDataStream =
      errorSubject
      .map { error -> (String, String) in
        let nsError = error as NSError
        return (nsError.localizedDescription, (nsError.localizedRecoverySuggestion ?? "エラーが発生しました。"))
      }
      .sink(receiveValue: { [dispatcher] in dispatcher.dispatch(.updateErrorMessage($0.0, $0.1)) })

    // errorSubjectにerrorが送られてきたら、エラーメッセージを表示
    let errorStream =
      errorSubject
      .map { _ in }
      .sink(receiveValue: { [dispatcher] in dispatcher.dispatch(.showError) })

    cancellables += [
      initialSearchStream,
      responseDataStream,
      emptyDataStream,
      isEmptyErrorStream,
      additionalResponseDataStream,
      errorDataStream,
      errorStream,
    ]
  }
}
