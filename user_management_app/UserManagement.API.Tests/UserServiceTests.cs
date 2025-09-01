using Microsoft.EntityFrameworkCore;
using UserManagement.API.Data;
using UserManagement.API.Models;
using UserManagement.API.Services;
using Xunit;

namespace UserManagement.API.Tests
{
    public class UserServiceTests : IDisposable
    {
        private readonly ApplicationDbContext _context;
        private readonly UserService _userService;

        public UserServiceTests()
        {
            var options = new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase(databaseName: $"TestDatabase_{Guid.NewGuid()}")
                .Options;
            
            _context = new ApplicationDbContext(options);
            _userService = new UserService(_context);
            
            // Initialize the database
            _context.Database.EnsureCreated();
        }

        public void Dispose()
        {
            _context.Database.EnsureDeleted();
            _context.Dispose();
        }

        [Fact]
        public async Task CreateUserAsync_ValidUser_ReturnsUserWithId()
        {
            // Arrange
            var user = new User 
            { 
                FirstName = "John", 
                LastName = "Doe", 
                Email = "john.doe@example.com" 
            };

            // Act
            var result = await _userService.CreateUserAsync(user);

            // Assert
            Assert.NotNull(result);
            Assert.True(result.Id > 0);
            Assert.Equal("John", result.FirstName);
            Assert.Equal("john.doe@example.com", result.Email);
        }

        [Fact]
        public async Task CreateUserAsync_MissingEmail_ThrowsArgumentException()
        {
            // Arrange
            var user = new User 
            { 
                FirstName = "John", 
                LastName = "Doe", 
                Email = "" 
            };

            // Act & Assert
            await Assert.ThrowsAsync<ArgumentException>(() => 
                _userService.CreateUserAsync(user));
        }

        [Fact]
        public async Task GetUsersAsync_WithUsers_ReturnsUserList()
        {
            // Arrange
            var user1 = new User { FirstName = "John", LastName = "Doe", Email = "john@example.com" };
            var user2 = new User { FirstName = "Jane", LastName = "Smith", Email = "jane@example.com" };
            
            await _userService.CreateUserAsync(user1);
            await _userService.CreateUserAsync(user2);

            // Act
            var result = await _userService.GetUsersAsync();

            // Assert
            Assert.NotNull(result);
            Assert.Equal(2, result.Count);
            Assert.Contains(result, u => u.Email == "john@example.com");
            Assert.Contains(result, u => u.Email == "jane@example.com");
        }

        [Fact]
        public async Task GetUsersAsync_EmptyDatabase_ReturnsEmptyList()
        {
            // Act
            var result = await _userService.GetUsersAsync();

            // Assert
            Assert.NotNull(result);
            Assert.Empty(result);
        }
    }
}