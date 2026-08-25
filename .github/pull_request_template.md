## Summary

Describe the problem and the solution. Keep the pull request focused on one
change and link any related issue or discussion.

## Validation

- [ ] `yarn verify`
- [ ] Android example build, library lint, and native unit tests (required when Android or shared native behavior changes)
- [ ] iOS example build (required when iOS or shared native behavior changes)
- [ ] Physical-device and printer validation, or a clear explanation of why it is not applicable

## Compatibility evidence

For Bluetooth transport, ESC/POS command, encoding, chunking, or image changes,
list each tested combination:

| Platform and OS | Printer model and firmware | Transport | Paper width | Payload | Result |
| --------------- | -------------------------- | --------- | ----------- | ------- | ------ |
| Not applicable  | Not applicable             | —         | —           | —       | —      |

## Checklist

- [ ] Public API changes are backward compatible or explicitly documented as breaking
- [ ] Tests cover the changed behavior and relevant failure paths
- [ ] Documentation and `CHANGELOG.md` are updated when user-visible behavior changes
- [ ] No secrets, generated build outputs, debug logs, or unrelated changes are included
