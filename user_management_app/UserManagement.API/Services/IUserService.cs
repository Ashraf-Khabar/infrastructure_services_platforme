using UserManagement.API.Models;

namespace UserManagement.API.Services
{
    public interface IUserService
    {
        Task<List<User>> GetAllUsersAsync();
        Task<User?> GetUserByIdAsync(int id);
        Task<User?> GetUserByEmailAsync(string email);
        Task<User?> GetUserByUsernameAsync(string username);
        Task<User> CreateUserAsync(User user);
        Task<User?> UpdateUserAsync(int id, User user);
        Task<bool> DeleteUserAsync(int id);
        Task<bool> ToggleUserStatusAsync(int id);
        Task<int> GetUsersCountAsync();
        Task<int> GetActiveUsersCountAsync();
        Task<List<User>> SearchUsersAsync(string searchTerm);
    }
}