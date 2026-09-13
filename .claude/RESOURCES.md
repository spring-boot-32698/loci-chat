# Loci Codebase — Resources

## Knowledge

- [Project `docs/` folder](docs/README.md) — the primary reference for this codebase: business overview, tech stack, architecture diagrams, business-flow sequence diagrams, data model, API reference, infrastructure. Generated directly from the source tree in this session. Use for: any "how does X work here" question.
- [Root `README.md`](../README.md) — quick-start run instructions, feature screenshots/GIFs, and the author's own architecture/hexagonal/DDD diagrams (`assets/architecture.png`, `assets/hexagonal.png`, `assets/ddd-modeling.png`). Use for: a visual gut-check against `docs/03-architecture.md`.
- [Spring Boot 3 reference documentation](https://docs.spring.io/spring-boot/index.html) — official docs for the backend framework version in use (3.5.3). Use for: any Spring-specific configuration question (Actuator, Flyway integration, WebSocket support).
- [Keycloak documentation](https://www.keycloak.org/documentation) — official docs for the IdP this project delegates auth to. Use for: understanding realms/clients/JWT claims referenced in `common/authentication`.
- [Angular documentation](https://angular.dev) — official docs, version-matched to this project's Angular 20. Use for: frontend module/routing questions.

## Gaps

- No resource yet on **Hexagonal Architecture / Ports & Adapters** or **tactical DDD** specifically — this project is a strong *example* of both, but a primary text (e.g. Alistair Cockburn's original hexagonal architecture writeup, or Vaughn Vernon's *Implementing Domain-Driven Design*) hasn't been sourced yet. Worth adding before a lesson goes deep on `common/ddd`'s stereotypes.
- No resource yet on **STOMP over WebSocket** semantics (topic vs. queue, `/user` destination convention) beyond the Spring docs — useful once real-time messaging lessons get built out.

## Wisdom (Communities)

Not yet discussed with the user — revisit once a specific sticking point (e.g. a
Hexagonal Architecture design question) comes up worth taking to a community like
r/SpringBoot or r/java.
