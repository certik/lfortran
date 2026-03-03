! Test: self-referential PDT with type-bound procedure
module pdt_11_mod
  implicit none
  type t(k)
    integer, kind :: k = kind(1.)
    type(t(k)), allocatable :: next
  contains
    procedure :: has_next
  end type
contains
  function has_next(self) result(r)
    class(t), intent(in) :: self
    logical :: r
    r = allocated(self%next)
  end function
end module

program pdt_11
  use pdt_11_mod
  implicit none
  type(t) :: a
  type(t) :: b

  if (a%has_next()) error stop
  allocate(a%next)
  if (.not. a%has_next()) error stop
  if (a%next%has_next()) error stop

  if (allocated(b%next)) error stop
  print *, "ok"
end program
