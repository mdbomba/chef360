# Glossary

## A

**Agent**: Software installed on nodes that communicates with Chef 360 Platform.

**API Gateway**: Central service that validates and routes requests from users, agents, and third-party services.

**Application Key**: Credentials used for node self-enrollment.

**Archive**: Removing a node from active management while preserving its data.

**Assembly (Skill)**: A grouping of skills deployed to nodes together.

**Attribute**: A named key/value pair describing a node's properties or state.

**Authorization (RBAC)**: Role-based access control for API endpoints.

## B

**Blackout Window**: A scheduled time period where jobs aren't permitted to run.

**Bulk Enrollment**: Enrolling multiple nodes simultaneously.

## C

**Canister**: A containerized package for skills.

**Chef DSM**: Chef Declarative State Management - central configuration data repository.

**Chef Infra Client**: Configuration management agent that retrieves cookbooks and recipes from DSM.

**Chef InSpec**: Compliance testing framework.

**Chef Courier**: Job execution and orchestration service.

**Cohort**: A group of nodes with common management settings.

## D

**Dispatcher**: Central Courier service that sends job definitions to nodes.

**DSM**: Declarative State Management.

## E

**Enrollment**: The process of bringing nodes under Chef 360 Platform management.

**Exception**: A scheduled time window where jobs are excluded from running.

## G

**Gohai**: System information collection tool.

## I

**Interpreter**: A service invoked by the Courier Runner to execute specific step types.

## J

**Job**: A unit of work defining actions, schedule, nodes, and error compensations.

**Job Action**: Workloads with payloads executed during a job run.

**Job Instance**: A single occurrence of a job execution.

**Job Run**: The assigned job instance for a specific node.

**Job Step**: An individual command executed for an action.

## M

**MCP**: Model Context Protocol - protocol for AI model integration.

**Multi-tenant**: Architecture supporting multiple isolated customer environments.

## N

**Node**: A physical or virtual resource accessible over a network.

**Node Account**: Registration and credential management for nodes.

**Node Filter**: SQL-like expression for identifying node sets.

**Node List**: Static, user-managed list of nodes.

**Node Management**: Service for managing nodes and their configurations.

## O

**OU (Organizational Unit)**: Internal grouping of users and node resources.

**Orchestrator**: Service that breaks jobs into discrete steps for individual nodes.

## P

**Payload**: Interpreter-specific configuration for job steps.

**Policy**: Permission definition for API endpoint access.

**Policyfile**: Chef configuration policy for cookbooks and dependencies.

**Provider**: External identity system (OAuth, SAML, OpenID Connect).

## R

**RBAC**: Role-Based Access Control.

**Role**: A mapping to one or more specific policies, assigned to users/OUs/agents.

**Runner**: Service on nodes that interprets and executes job definitions.

## S

**Sentry**: Service that monitors Orchestrator Workers and retries failed jobs.

**Skill**: An agent installed on nodes for a specific outcome.

**Slug**: Short name for internal service routing.

**Skill Assembly**: A collection of skills deployed to nodes.

**Skill Lifecycle Hook**: Custom script executed during skill install/update/delete.

## T

**Tag**: User-provided custom attribute for grouping nodes.

**Tenant**: Fundamental security boundary in Chef 360 Platform.

## W

**Worker**: Background service that processes jobs (Scheduler Worker, Orchestrator Worker).
