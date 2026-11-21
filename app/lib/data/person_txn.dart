import 'db.dart';
import 'people_repo.dart';

extension PersonTxn on AppDatabase {
  /// Re-links an existing transaction to a person (replaces old ledger rows for it).
  Future<void> relinkTxn(Txn t, int personId) async {
    await db.delete('ledger', where: 'txn_id = ?', whereArgs: [t.id]);
    await this.linkTxn(t, personId);
  }

  /// Removes ledger rows that belonged to a transaction (when it is no longer a person transfer).
  Future<void> unlinkTxnLedger(int txnId) async {
    await db.delete('ledger', where: 'txn_id = ?', whereArgs: [txnId]);
    await db.update('transactions', {'person_id': null},
        where: 'id = ?', whereArgs: [txnId]);
  }
}
