using Microsoft.EntityFrameworkCore;
using UserManagement.API.Data;
using UserManagement.API.Services;

try
{
    Console.WriteLine("Starting UserManagement API...");
    
    var builder = WebApplication.CreateBuilder(args);

    builder.Logging.AddConsole();
    builder.Logging.AddDebug();
    
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();

    // Configuration PostgreSQL
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    Console.WriteLine($"Connection string: {connectionString}");

    builder.Services.AddDbContext<ApplicationDbContext>(options =>
    {
        options.UseNpgsql(connectionString, sqlOptions => 
        {
            sqlOptions.EnableRetryOnFailure(
                maxRetryCount: 5,
                maxRetryDelay: TimeSpan.FromSeconds(30),
                errorCodesToAdd: null);
        });
        options.EnableDetailedErrors();
        options.EnableSensitiveDataLogging();
    });

    builder.Services.AddScoped<IUserService, UserService>();
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("AllowAll", policy =>
        {
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        });
    });

    var app = builder.Build();

    app.UseCors("AllowAll");
    
    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI();
    }

    app.UseAuthorization();
    app.MapControllers();

    // Gestion des erreurs de migration
    try
    {
        using (var scope = app.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            Console.WriteLine("Running database migrations...");
            
            // Attendre que la DB soit disponible
            var retries = 10;
            while (retries > 0)
            {
                try
                {
                    dbContext.Database.Migrate();
                    Console.WriteLine("Database migrations completed successfully");
                    break;
                }
                catch (Npgsql.NpgsqlException ex) when (ex.Message.Contains("connection"))
                {
                    retries--;
                    Console.WriteLine($"Database not ready yet. Retries left: {retries}");
                    if (retries == 0) throw;
                    Thread.Sleep(5000);
                }
            }
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Database migration failed: {ex.Message}");
        // Ne pas arrêter l'application si la migration échoue
    }

    // Endpoint de santé
    app.MapGet("/health", () => 
    {
        try
        {
            using var scope = app.Services.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            return dbContext.Database.CanConnect() ? "Healthy" : "Unhealthy";
        }
        catch
        {
            return "Unhealthy";
        }
    });

    Console.WriteLine("Application started successfully");
    // Ajoutez ceci AVANT app.Run();
app.MapGet("/test", () => "API is working!");
app.MapGet("/test-db", async (ApplicationDbContext context) => 
{
    try
    {
        var canConnect = await context.Database.CanConnectAsync();
        return canConnect ? "Database connected" : "Database connection failed";
    }
    catch (Exception ex)
    {
        return $"Database error: {ex.Message}";
    }
});

app.MapGet("/api/users/test", async (ApplicationDbContext context) =>
{
    try
    {
        var users = await context.Users.ToListAsync();
        return Results.Ok(users);
    }
    catch (Exception ex)
    {
        return Results.Problem($"Error: {ex.Message}");
    }
});

app.MapPost("/api/users/test", async (ApplicationDbContext context, User user) =>
{
    try
    {
        context.Users.Add(user);
        await context.SaveChangesAsync();
        return Results.Created($"/api/users/{user.Id}", user);
    }
    catch (Exception ex)
    {
        return Results.Problem($"Error: {ex.Message}");
    }
});
    app.Run();
}
catch (Exception ex)
{
    Console.WriteLine($"Fatal error during startup: {ex}");
    throw;
}