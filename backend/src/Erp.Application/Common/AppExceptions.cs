namespace Erp.Application.Common;

public class NotFoundAppException(string entity, object id) : Exception($"{entity} '{id}' was not found.");

public class ValidationAppException(string message) : Exception(message);

public class ConflictAppException(string message) : Exception(message);

public class ForbiddenAppException(string message = "You do not have permission to perform this action.") : Exception(message);
