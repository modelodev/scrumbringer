# Persistence Boundaries

`repository/auth` is an intentional SQL boundary for authentication bootstrap,
login, and registration flows. Those flows span users, organizations, invites,
and initial memberships, so keeping their low-level queries together is clearer
than forcing them into the `use_case/*_db.gleam` convention.

Business logic should stay in `use_case/*` modules. New repository packages
should only be added when a flow needs shared SQL helpers across multiple
runtime use_case.
