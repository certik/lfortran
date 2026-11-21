! Generic initializers (DI extension E8) and their overloading (E9): generic
! initializers that are not distinguishable, in a type and in an implements
! statement; a reference that no initializer and not the structure
! constructor accepts, with the reason of each candidate; braces after the
! name of a type that is not generic; an unmet constraint of a generic
! initializer; and a type name designating a type whose only initializers
! are generic.
module continue_compilation_traits_generic_init_m
    implicit none
    private
    public :: IPrinter, Printer, Factory, Num, Pair, Holder, ctor0, ctor1, &
        use_ctor0

    abstract interface :: IPrinter
        integer function width(self)
            type(itself), intent(in), pass :: self
        end function width
    end interface IPrinter

    abstract interface :: INumeric
        integer | real(4) | real(8)
    end interface INumeric

    type, implements(IPrinter) :: Printer
    contains
        procedure :: width => printer_width
    end type Printer

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0

        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1
    end interface

    ! Private components: no structure constructor outside the module.
    type :: Factory
        private
        integer :: arity = -1
    contains
        initial :: init0, init1
    end type Factory

    abstract interface
        function plain0() result(res)
            import :: Factory
            type(Factory) :: res
        end function plain0
    end interface

    type :: Num
        integer :: k = 0
    contains
        initial :: num_from_int, num_from
    end type Num

    ! Two generic initializers that every numeric argument matches.
    type :: Pair
        integer :: k = 0
    contains
        initial :: pair_a, pair_b
    end type Pair

    type :: Holder
        integer :: k = 0
    end type Holder

    ! The same in an implements statement.
    implements :: Holder
        initial :: holder_a, holder_b
    end implements Holder

contains

    integer function printer_width(self)
        class(Printer), intent(in) :: self
        printer_width = 80
    end function printer_width

    function init0{U}(ctor) result(self)
        procedure(ctor0{U}) :: ctor
        type(Factory) :: self
        self%arity = 0
    end function init0

    function init1{Trait :: T1, IPrinter :: U}(ctor) result(self)
        procedure(ctor1{T1,U}) :: ctor
        type(Factory) :: self
        self%arity = 1
    end function init1

    function num_from_int(x) result(self)
        integer, intent(in) :: x
        type(Num) :: self
        self%k = x
    end function num_from_int

    function num_from{INumeric :: T}(x) result(self)
        type(T), intent(in) :: x
        type(Num) :: self
        self%k = 1
    end function num_from

    function pair_a{INumeric :: T}(x) result(self)
        type(T), intent(in) :: x
        type(Pair) :: self
        self%k = 1
    end function pair_a

    function pair_b{T}(y) result(self)
        type(T), intent(in) :: y
        type(Pair) :: self
        self%k = 2
    end function pair_b

    function holder_a{T}(x) result(self)
        type(T), intent(in) :: x
        type(Holder) :: self
        self%k = 1
    end function holder_a

    function holder_b{INumeric :: T}(x) result(self)
        type(T), intent(in) :: x
        type(Holder) :: self
        self%k = 2
    end function holder_b

    integer function use_ctor0(f)
        procedure(plain0) :: f
        type(Factory) :: p
        p = f()
        use_ctor0 = p%arity
    end function use_ctor0

end module continue_compilation_traits_generic_init_m

program continue_compilation_traits_generic_init
    use continue_compilation_traits_generic_init_m, only: IPrinter, Printer, &
        Factory, Num, use_ctor0
    implicit none
    type(Factory) :: f
    type(Num) :: a
    integer :: n

    ! No initializer accepts a character argument, and the structure
    ! constructor's component is private.
    f = Factory("text")
    ! The constraint IPrinter :: U of init1 fails for U = Num.
    f = Factory(make_num)
    ! Braces after the name of a type that is not generic.
    a = Num{real}(1.5)
    ! No initializer accepts two arguments; the structure constructor has one
    ! component.
    a = Num(1, 2)
    ! Factory has only generic initializers, which are not designated yet.
    n = use_ctor0(Factory)

contains

    function make_num(p) result(r)
        class(IPrinter), intent(in) :: p
        type(Num) :: r
        r = Num(p%width())
    end function make_num

end program continue_compilation_traits_generic_init
