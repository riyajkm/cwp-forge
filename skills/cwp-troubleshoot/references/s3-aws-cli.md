# S3 / AWS CLI pitfalls (Contabo and other Ceph-based S3) [V]

- AWS CLI v1 (1.18) crashes with "argument of type 'NoneType' is not iterable" when the S3 error has an empty `<Message>`.
- AWS CLI v2 shows the real code for most calls; some (e.g. `NoSuchLifecycleConfiguration`) still crash. Read `<Code>` from `--debug` output.
- Use path-style addressing; never put the bucket in the endpoint.
- Defaults: ~10 MB/s, 250 req/s. Single PUTs over ~200 MB reported blocked; use multipart.
- Test credentials in the shell with the same endpoint before blaming the panel.
- Never paste access keys into logs, chats or tickets.
