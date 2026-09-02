! C815 An entity shall not be explicitly given any attribute more than once
! in a scoping unit.  (Distinct from C801: the attribute is repeated across
! statements, not within one type-declaration-stmt.)
subroutine c815_allocatable_stmt()
    implicit none
    integer, allocatable :: b(:)
    allocatable :: b   ! {error C815 allocatable-stmt}
    allocate(b(2))
end subroutine
subroutine c815_dimension_stmt()
    implicit none
    integer, dimension(3) :: a
    dimension :: a(3)   ! {error C815 dimension-stmt}
    a = 1
end subroutine
subroutine c815_intent_stmt(x)
    implicit none
    integer, intent(in) :: x
    intent(in) :: x   ! {error C815 intent-stmt}
end subroutine
subroutine c815_save_twice()
    implicit none
    integer, save :: n = 0
    save :: n   ! {error C815 save-stmt}
    n = n + 1
end subroutine
module c815_public_twice
    implicit none
    integer, public :: m = 1
    public :: m   ! {error C815 access-stmt}
end module
