class AddReviewQueueIndexes < ActiveRecord::Migration[8.1]
  def change
    # The tables' status filter always sorts by name and takes one page, so the
    # sort belongs in the index: 1.51ms → 0.06ms at 20k rows. Status alone only
    # reached 1.03ms — nine rows in ten are active, so it carries no selectivity.
    add_index :vendors, [ :status, :name ]
    add_index :systems, [ :status, :name ]

    # The review queue only ever asks about active vendors. Partial beats both a
    # plain and a composite index here, and a plain index on these two columns
    # measured slower than no index at all on the broad queries (30% of rows).
    add_index :vendors, :next_review_on, where: "status = 'active'",
              name: "index_vendors_on_next_review_on_active"
    add_index :vendors, :last_assessed_on, where: "status = 'active'",
              name: "index_vendors_on_last_assessed_on_active"
  end
end
