//
//  AddSyncRecordPage.swift
//  ErgoServer
//
//  Created by Adon Omeri on 6/11/2026.
//

import Fluent
import SQLKit

/// Adds the owning page's id to `sync_records`, empty for every kind but statements and links, so pruning can find
/// what a deleted page leaves behind without opening every sealed row. SQLite adds a nullable column in place.
struct AddSyncRecordPage: AsyncMigration {
	func prepare(on database: any Database) async throws {
		try await database.transaction { database in
			guard let sql = database as? any SQLDatabase else {
				throw ServerConfig.Problem(description: "Expected an SQL database to add sync record pages")
			}
			try await sql.raw("ALTER TABLE sync_records ADD COLUMN page_id TEXT").run()
			try await sql.create(index: "sync_records_account_page").on(SyncRecordRow.schema).column("account_id").column("page_id").run()
		}
	}

	func revert(on _: any Database) async throws {
		throw ServerConfig.Problem(description: "AddSyncRecordPage can't be reverted, restore a backup instead")
	}
}
