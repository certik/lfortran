module traits_implicit_access_01_mod
   private
   public :: ISomeTrait, Rtrait, Counter, count_up
   abstract interface :: ISomeTrait
   end interface
   abstract interface :: Rtrait
   end interface
   type :: Counter
      integer :: n = 0
   end type Counter
contains
   subroutine count_up(c)
      type(Counter), intent(inout) :: c
      c%n = c%n + 1
   end subroutine count_up
end module traits_implicit_access_01_mod

program traits_implicit_access_01
   use traits_implicit_access_01_mod
   type(Counter) :: c
   call count_up(c)
   call count_up(c)
   if (c%n /= 2) error stop
end program traits_implicit_access_01
