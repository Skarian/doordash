# Workspace Instructions

## Project boundaries

Keep the Linux port and authentication workflows provider neutral. Hosting
provider behavior belongs under `integrations/<provider>/` and must configure,
not fork, the generic workflows.

## User preferences

For shopping, delivery, grocery, or retail-order tasks, read
`preferences/ordering.md` before searching for or selecting products.

Treat that file as the user's persistent ordering preferences. A preference
applies unless the user explicitly requests something different in the current
conversation.
