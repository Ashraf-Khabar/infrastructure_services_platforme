using Microsoft.AspNetCore.Mvc;
using Moq;
using UserManagement.API.Controllers;
using UserManagement.API.Models;
using UserManagement.API.Services;
using Xunit;

namespace UserManagement.API.Tests
{
    public class UsersControllerTests
    {
        private readonly Mock<IUserService> _mockUserService;
        private readonly UsersController _controller;

        public UsersControllerTests()
        {
            _mockUserService = new Mock<IUserService>();
            _controller = new UsersController(_mockUserService.Object);
        }

        [Fact]
        public async Task GetUsers_ReturnsOkWithUsers()
        {
            // Arrange
            var users = new List<User>
            {
                new User { Id = 1, FirstName = "John", LastName = "Doe", Email = "john@example.com" },
                new User { Id = 2, FirstName = "Jane", LastName = "Smith", Email = "jane@example.com" }
            };
            
            _mockUserService.Setup(s => s.GetUsersAsync()).ReturnsAsync(users);

            // Act
            var result = await _controller.GetUsers();

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var returnedUsers = Assert.IsType<List<User>>(okResult.Value);
            Assert.Equal(2, returnedUsers.Count);
        }

        [Fact]
        public async Task CreateUser_ValidUser_ReturnsCreatedResult()
        {
            // Arrange
            var user = new User { FirstName = "John", LastName = "Doe", Email = "john@example.com" };
            var createdUser = new User { Id = 1, FirstName = "John", LastName = "Doe", Email = "john@example.com" };
            
            _mockUserService.Setup(s => s.CreateUserAsync(user)).ReturnsAsync(createdUser);

            // Act
            var result = await _controller.CreateUser(user);

            // Assert
            var createdResult = Assert.IsType<CreatedAtActionResult>(result);
            Assert.Equal("GetUsers", createdResult.ActionName);
            Assert.Equal(1, ((User)createdResult.Value).Id);
        }

        [Fact]
        public async Task CreateUser_ServiceThrowsException_ReturnsBadRequest()
        {
            // Arrange
            var user = new User { FirstName = "John", LastName = "Doe", Email = "invalid" };
            
            _mockUserService.Setup(s => s.CreateUserAsync(user))
                .ThrowsAsync(new ArgumentException("Invalid email"));

            // Act
            var result = await _controller.CreateUser(user);

            // Assert
            var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Equal("Invalid email", badRequestResult.Value);
        }
    }
}