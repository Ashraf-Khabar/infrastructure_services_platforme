using UserManagement.API.Models;

namespace UserManagement.API.Services
{
    public interface IUserService
    {
        Task CreateUserAsync(User user);
        Task<List<User>> GetUsersAsync();
    }
}