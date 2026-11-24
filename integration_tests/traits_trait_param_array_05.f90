! Regression test for https://github.com/lfortran/lfortran/issues/18620:
! typed allocate(Entry{U} :: self%elements(1)) inside a generic derived type
! parameterized over a trait, instantiated on a concrete trait and executed.
! GFortran does not accept this LFortran extension.
module traits_trait_param_array_05_m
    implicit none

    abstract interface :: IValue
        integer function get(self)
            type(itself), pass, intent(in) :: self
        end function get
    end interface IValue

    type, implements(IValue) :: Num
        integer :: n = 0
    contains
        procedure :: get => num_get
    end type Num

    type :: Entry{trait :: U}
        class(U), allocatable :: elem
    end type Entry

    type, public, sealed :: Vector{trait :: U}
        type(Entry{U}), allocatable :: elements(:)
    contains
        initial :: init
    end type Vector

contains

    integer function num_get(self)
        class(Num), intent(in) :: self
        num_get = self%n
    end function num_get

    function init() result(self)
        type(Vector{U}) :: self
        allocate(Entry{U} :: self%elements(1))
    end function init

end module traits_trait_param_array_05_m

program traits_trait_param_array_05
    use traits_trait_param_array_05_m
    implicit none
    type(Vector{IValue}) :: v

    v = Vector{IValue}()
    if (.not. allocated(v%elements)) error stop 1
    if (size(v%elements) /= 1) error stop 2
    v%elements(1)%elem = Num(42)
    if (v%elements(1)%elem%get() /= 42) error stop 3
end program traits_trait_param_array_05
