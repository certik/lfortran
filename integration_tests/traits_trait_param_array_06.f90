! Working Vector{trait::U} example for https://github.com/lfortran/lfortran/issues/18654:
! `Vector{trait::U}` stores and appends `class(U)` values without calling
! trait-specific methods inside the generic. Code that knows the concrete
! trait (`type(Vector{IPrintable})`) calls `print()` on the stored elements.
! GFortran does not accept this LFortran extension.
module traits_trait_param_array_06_types
    implicit none

    abstract interface :: IPrintable
        subroutine print_item(self, out_val)
            type(itself), pass, intent(in) :: self
            integer, intent(out) :: out_val
        end subroutine print_item
    end interface

    type, sealed, implements(IPrintable) :: Wrapper
        integer :: n
    contains
        procedure :: print_item => wrapper_print
    end type Wrapper

contains

    subroutine wrapper_print(self, out_val)
        type(Wrapper), intent(in) :: self
        integer, intent(out) :: out_val
        out_val = self%n
    end subroutine wrapper_print

end module traits_trait_param_array_06_types

module traits_trait_param_array_06_vector
    implicit none
    private

    type, public :: Entry{trait :: U}
        class(U), allocatable :: elem
    end type Entry

    type, public, sealed :: Vector{trait :: U}
        private
        logical :: start = .true.
        type(Entry{U}), allocatable :: elements(:)
    contains
        initial :: init
        procedure, pass :: append
        procedure, pass :: length
        procedure, pass :: item
    end type Vector

contains

    function init() result(self)
        type(Vector{U}) :: self
        allocate(Entry{U} :: self%elements(1))
    end function init

    subroutine append(self, val)
        type(Vector{U}), intent(inout) :: self
        class(U), intent(in) :: val
        if (self%start) then
            self%elements(1)%elem = val
            self%start = .false.
        else
            self%elements = [self%elements, Entry{U}(val)]
        end if
    end subroutine append

    integer function length(self)
        type(Vector{U}), intent(in) :: self
        if (self%start) then
            length = 0
        else
            length = size(self%elements)
        end if
    end function length

    function item(self, idx) result(res)
        type(Vector{U}), intent(in) :: self
        integer, intent(in) :: idx
        class(U), allocatable :: res
        res = self%elements(idx)%elem
    end function item

end module traits_trait_param_array_06_vector

program traits_trait_param_array_06
    use traits_trait_param_array_06_types
    use traits_trait_param_array_06_vector, only: Vector
    implicit none

    type(Vector{IPrintable}) :: vec
    class(IPrintable), allocatable :: elem
    integer :: i, val, total

    vec = Vector{IPrintable}()
    call vec%append(Wrapper(0))
    call vec%append(Wrapper(10))
    call vec%append(Wrapper(20))

    if (vec%length() /= 3) error stop 1
    total = 0
    do i = 1, vec%length()
        elem = vec%item(i)
        call elem%print_item(val)
        if (val /= (i - 1) * 10) error stop 2
        total = total + val
    end do
    if (total /= 30) error stop 3
end program traits_trait_param_array_06
