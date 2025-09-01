using System.ComponentModel.DataAnnotations;

namespace UserManagement.Client.Models
{
    public class User
    {
        public int Id { get; set; }
        
        [Required(ErrorMessage = "Le prénom est requis")]
        public string FirstName { get; set; } = string.Empty;
        
        [Required(ErrorMessage = "Le nom est requis")]
        public string LastName { get; set; } = string.Empty;
        
        [Required(ErrorMessage = "L'email est requis")]
        [EmailAddress(ErrorMessage = "Format d'email invalide")]
        public string Email { get; set; } = string.Empty;
        
        public string? PhoneNumber { get; set; }
        
        public DateTime CreatedAt { get; set; } = DateTime.Now;
        public DateTime? UpdatedAt { get; set; }
        public bool IsActive { get; set; } = true;
    }
}