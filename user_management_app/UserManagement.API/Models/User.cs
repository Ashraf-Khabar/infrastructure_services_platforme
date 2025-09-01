using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace UserManagement.API.Models
{
    public class User
    {
        public int Id { get; set; }
        
        [Required]
        [StringLength(100)]
        public string FirstName { get; set; } = string.Empty;
        
        [Required]
        [StringLength(100)]
        public string LastName { get; set; } = string.Empty;
        
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;
        
        [Phone]
        public string? PhoneNumber { get; set; }
        
        [Required]
        [StringLength(100)]
        public string Username { get; set; } = string.Empty;
        
        [JsonIgnore]
        public string PasswordHash { get; set; } = string.Empty;
        
        public UserRole Role { get; set; } = UserRole.User;
        
        public DateTime DateOfBirth { get; set; }
        
        public string? Address { get; set; }
        
        public string? City { get; set; }
        
        public string? Country { get; set; }
        
        public string? PostalCode { get; set; }
        
        public bool IsActive { get; set; } = true;
        
        public bool EmailVerified { get; set; } = false;
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        
        public DateTime? UpdatedAt { get; set; }
        
        public DateTime? LastLogin { get; set; }
    }

    public enum UserRole
    {
        Admin,
        Moderator,
        User
    }
}