using Microsoft.EntityFrameworkCore;
using UserManagement.API.Data;
using UserManagement.API.Models;

namespace UserManagement.API.Services
{
    public class UserService : IUserService
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<UserService> _logger;

        public UserService(ApplicationDbContext context, ILogger<UserService> logger)
        {
            _context = context;
            _logger = logger;
        }

        public async Task<User> CreateUserAsync(User user)
        {
            try
            {
                // Validation
                if (string.IsNullOrEmpty(user.FirstName))
                    throw new ArgumentException("Le prénom est requis");

                if (string.IsNullOrEmpty(user.LastName))
                    throw new ArgumentException("Le nom est requis");

                if (string.IsNullOrEmpty(user.Email))
                    throw new ArgumentException("L'email est requis");

                // Vérifier si l'email existe déjà
                if (await _context.Users.AnyAsync(u => u.Email == user.Email))
                    throw new InvalidOperationException("Un utilisateur avec cet email existe déjà");

                // Set default values
                user.CreatedAt = DateTime.UtcNow;
                user.IsActive = true;

                _context.Users.Add(user);
                await _context.SaveChangesAsync();
                
                _logger.LogInformation("User created successfully: {Email}", user.Email);
                return user;
            }
            catch (DbUpdateException ex)
            {
                _logger.LogError(ex, "Database error while creating user");
                throw new Exception("Erreur de base de données");
            }
        }

        public async Task<List<User>> GetUsersAsync()
        {
            try
            {
                return await _context.Users.ToListAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting users");
                throw;
            }
        }
    }
}