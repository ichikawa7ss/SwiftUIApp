//
//  UserRepository.swift
//  Infrastructure
//
//  Created by Yuki Okudera on 2022/01/17.
//  Copyright © 2022 yuoku. All rights reserved.
//

import Combine
import Domain
import Injected

public struct UserRepository: UserRepositoryProviding {

  public init() {}

  @Injected(\.apiClientProvider)
  private var apiClient: APIClientProviding

  public func response(searchQuery: String, page: Int) -> AnyPublisher<UserAggregateRoot, Domain.APIError> {
    apiClient.response(from: SearchUserRequest(searchQuery: searchQuery, page: page))
      .map { apiResponse in
        let userIDs = apiResponse.response.items.map { $0.id.description }
        let usersByID = apiResponse.response.items.reduce(into: [String: UserEntity]()) {
          $0[$1.id.description] = UserEntity(
            id: $1.id.description,
            login: $1.login,
            avatarUrl: $1.avatarUrl,
            htmlUrl: $1.htmlUrl,
            type: $1.type
          )
        }
        return UserAggregateRoot(
          page: page + 1,
          hasNext: apiResponse.gitHubAPIPagination?.hasNext ?? false,
          userIDs: userIDs,
          usersByID: usersByID
        )
      }
      .mapError { APIError(error: $0).convertToDomainError() }
      .eraseToAnyPublisher()
  }
}
