
enum TodoStatus { pending, inProgress, done, cancelled }
enum TaskStatus { active, archived }
enum GoalType  { atLeast, atMost, exactly }

enum PomodoroStatus { running, completed, abandoned }
enum TaskLogStatus { done, notDone, skipped }

// Drift handles int<->enum via intEnum<T>() column builder natively —
// no manual converter needed for simple enums.
// Only write a custom converter if you need string storage.