package com.caoqiang.blog.shared.util;

import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/** Registers side effects that must follow the outcome of the current transaction. */
public final class TransactionCallbacks {

    private TransactionCallbacks() {}

    /**
     * Runs the callback after a successful commit, or immediately when no transaction is active.
     */
    public static void afterCommit(Runnable callback) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            callback.run();
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                callback.run();
            }
        });
    }

    /**
     * Registers rollback cleanup.
     *
     * @return {@code true} when the callback was attached to an active transaction
     */
    public static boolean afterRollback(Runnable callback) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            return false;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCompletion(int status) {
                if (status != STATUS_COMMITTED) {
                    callback.run();
                }
            }
        });
        return true;
    }
}
